FROM python:3.11-slim
WORKDIR /app
COPY server/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY server/app.py ./app.py
COPY server/invite.html ./invite.html
COPY server/invite-bg.jpg ./invite-bg.jpg
ENV PORT=8080 PYTHONUNBUFFERED=1
EXPOSE 8080
CMD ["python", "app.py"]
