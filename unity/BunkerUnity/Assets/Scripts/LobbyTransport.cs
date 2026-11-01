using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using UnityEngine;
using UnityEngine.Networking;

namespace Bunker.UnityPort
{
    // One request at a time: the aiohttp transport serializes each session and
    // drains its event queue. HTTPS polling also works on WebSocket-free hosts.
    public sealed class LobbyTransport : MonoBehaviour
    {
        public event Action<LobbyEvent> Event;
        public event Action<string> Status;
        public bool Connected { get; private set; }
        public string Root { get; private set; }
        private string token;
        private Coroutine pump;
        private readonly Queue<string> outgoing = new Queue<string>();
        private bool closing;

        public static bool TryNormalize(string address, bool allowHttp, out string root)
        {
            root = null;
            if (string.IsNullOrWhiteSpace(address)) return false;
            address = address.Trim();
            if (address.StartsWith("wss://", StringComparison.OrdinalIgnoreCase))
                address = "https://" + address.Substring(6);
            if (!Uri.TryCreate(address, UriKind.Absolute, out var uri)) return false;
            if (uri.Scheme != "https" && !(allowHttp && uri.Scheme == "http")) return false;
            if (!string.IsNullOrEmpty(uri.UserInfo) || !string.IsNullOrEmpty(uri.Query) || !string.IsNullOrEmpty(uri.Fragment)) return false;
            var path = uri.AbsolutePath.TrimEnd('/');
            if (path != "" && path != "/ws") return false;
            root = uri.GetLeftPart(UriPartial.Authority).TrimEnd('/');
            return true;
        }

        public bool Open(string address)
        {
            if (pump != null || Connected) return false;
#if UNITY_EDITOR
            const bool allowHttp = true;
#else
            const bool allowHttp = false;
#endif
            if (!TryNormalize(address, allowHttp, out var root))
            {
                Status?.Invoke("Введите защищённый адрес https://… или wss://…/ws");
                return false;
            }
            Root = root;
            closing = false;
            pump = StartCoroutine(Run());
            return true;
        }

        public bool Send(Command command)
        {
            if (!Connected || closing || command == null) return false;
            outgoing.Enqueue(JsonUtility.ToJson(command));
            return true;
        }
        public bool SendRadioPower(bool value)
        {
            if (!Connected || closing) return false;
            outgoing.Enqueue(JsonUtility.ToJson(new BooleanCommand { action = "radio_power", value = value }));
            return true;
        }
        public void Close()
        {
            closing = true;
            outgoing.Clear();
        }

        private IEnumerator Request(string path, string body, Action<string> success, Action<string> failure)
        {
            using (var req = new UnityWebRequest(Root + "/transport/" + path, "POST"))
            {
                req.uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(body));
                req.downloadHandler = new DownloadHandlerBuffer();
                req.SetRequestHeader("Content-Type", "application/json");
                if (!string.IsNullOrEmpty(token)) req.SetRequestHeader("X-Lobby-Session", token);
                req.timeout = 15;
                yield return req.SendWebRequest();
                if (req.result != UnityWebRequest.Result.Success)
                {
                    failure?.Invoke("Ошибка соединения: " + req.responseCode + " " + req.error);
                    yield break;
                }
                success?.Invoke(req.downloadHandler.text);
            }
        }

        private IEnumerator Run()
        {
            string text = null, error = null;
            Status?.Invoke("Подключение к серверу…");
            yield return Request("open", "{}", value => text = value, value => error = value);
            SessionResponse session = null;
            if (error == null)
            {
                try { session = JsonUtility.FromJson<SessionResponse>(text); }
                catch (ArgumentException) { error = "Некорректный ответ сервера"; }
            }
            if (error != null || session == null || string.IsNullOrEmpty(session.session))
            {
                Status?.Invoke(error ?? "Сервер не выдал сессию");
                pump = null;
                yield break;
            }
            token = session.session;
            Connected = true;
            Status?.Invoke("Подключено");
            string terminalError = null;
            while (!closing)
            {
                text = null; error = null;
                bool hasCommand = outgoing.Count > 0;
                var message = hasCommand ? outgoing.Dequeue() : "{}";
                yield return Request(hasCommand ? "send" : "poll", message, value => text = value, value => error = value);
                if (error != null)
                {
                    terminalError = error;
                    break;
                }
                Envelope envelope = null;
                try { envelope = JsonUtility.FromJson<Envelope>(text); }
                catch (ArgumentException) { error = "Некорректный ответ сервера"; }
                if (error != null || envelope == null || envelope.events == null)
                {
                    terminalError = error ?? "Ошибка: некорректные события сервера";
                    break;
                }
                foreach (var item in envelope.events)
                    if (item != null) Event?.Invoke(item);
                if (!hasCommand) yield return new WaitForSecondsRealtime(0.5f);
            }
            if (closing && !string.IsNullOrEmpty(token))
                yield return Request("close", "{}", _ => { }, _ => { });
            Connected = false;
            token = null;
            outgoing.Clear();
            pump = null;
            if (closing) Status?.Invoke("Соединение закрыто");
            else if (terminalError != null) Status?.Invoke(terminalError);
        }
    }
}
