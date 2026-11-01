using UnityEngine;
using UnityEngine.EventSystems;

namespace Bunker.UnityPort.World
{
    /// <summary>
    /// First-person locomotion without visible sticks: a drag beginning on the
    /// left moves, one beginning on the right looks. A finger keeps its role
    /// until release, even when it crosses the centre. UI touches are ignored.
    /// Attach to a CharacterController and provide a child camera.
    /// </summary>
    [RequireComponent(typeof(CharacterController))]
    public sealed class BunkerTouchController : MonoBehaviour
    {
        public Transform cameraPivot;
        public float walkSpeed = 2.7f;
        public float gravity = 20f;
        public float lookDegreesPerScreen = 160f;
        public float moveRadiusFraction = .12f;
        public float topDistance = 9f;
        public float topHeight = 11f;
        private CharacterController motor;
        private int moveFinger = -1, lookFinger = -1;
        private Vector2 moveOrigin, movePosition;
        private float pitch, verticalSpeed;
        private bool topView;
        private Vector3 cameraLocalPosition;
        private Quaternion cameraLocalRotation;

        private void Awake()
        {
            motor = GetComponent<CharacterController>();
            if (cameraPivot == null)
            {
                enabled = false;
                Debug.LogError("BunkerTouchController requires a camera pivot");
                return;
            }
            cameraLocalPosition = cameraPivot.localPosition;
            cameraLocalRotation = cameraPivot.localRotation;
        }

        public void SetTopView(bool value)
        {
            if (cameraPivot == null || topView == value) return;
            topView = value;
            moveFinger = lookFinger = -1;
            if (topView)
            {
                cameraPivot.localPosition = new Vector3(0, topHeight, -topDistance);
                cameraPivot.localRotation = Quaternion.Euler(55, 0, 0);
            }
            else
            {
                cameraPivot.localPosition = cameraLocalPosition;
                cameraPivot.localRotation = cameraLocalRotation * Quaternion.Euler(pitch, 0, 0);
            }
        }

        private void Update()
        {
            foreach (Touch touch in Input.touches)
            {
                if (touch.phase == TouchPhase.Began)
                {
                    if (EventSystem.current != null && EventSystem.current.IsPointerOverGameObject(touch.fingerId)) continue;
                    if (touch.position.x < Screen.width * .5f && moveFinger < 0)
                    {
                        moveFinger = touch.fingerId;
                        moveOrigin = movePosition = touch.position;
                    }
                    else if (touch.position.x >= Screen.width * .5f && lookFinger < 0)
                        lookFinger = touch.fingerId;
                }
                if (touch.fingerId == moveFinger) movePosition = touch.position;
                if (touch.fingerId == lookFinger && touch.phase == TouchPhase.Moved)
                {
                    float scale = lookDegreesPerScreen / Mathf.Max(1, Screen.height);
                    transform.Rotate(0, touch.deltaPosition.x * scale, 0);
                    if (!topView)
                    {
                        pitch = Mathf.Clamp(pitch - touch.deltaPosition.y * scale, -75, 75);
                        cameraPivot.localRotation = cameraLocalRotation * Quaternion.Euler(pitch, 0, 0);
                    }
                }
                if (touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled)
                {
                    if (touch.fingerId == moveFinger) moveFinger = -1;
                    if (touch.fingerId == lookFinger) lookFinger = -1;
                }
            }
            Vector2 input = Vector2.zero;
            if (moveFinger >= 0)
            {
                float radius = Mathf.Max(1, Mathf.Min(Screen.width, Screen.height) * Mathf.Max(.01f, moveRadiusFraction));
                input = Vector2.ClampMagnitude((movePosition - moveOrigin) / radius, 1);
            }
            if (motor.isGrounded && verticalSpeed < 0) verticalSpeed = -2f;
            verticalSpeed -= gravity * Time.deltaTime;
            Vector3 horizontal = (transform.right * input.x + transform.forward * input.y) * walkSpeed;
            motor.Move((horizontal + Vector3.up * verticalSpeed) * Time.deltaTime);
        }

        private void OnDisable()
        {
            moveFinger = lookFinger = -1;
            verticalSpeed = 0;
        }
    }
}
