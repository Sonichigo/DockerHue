FROM python:3.12-slim
LABEL dockerhue.lang=python
WORKDIR /app
COPY app.py .
RUN useradd --uid 10001 --no-create-home hue
USER hue
EXPOSE 8080
CMD ["python", "app.py"]
