FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod main.go ./
RUN CGO_ENABLED=0 go build -o /hue .

FROM gcr.io/distroless/static-debian12:nonroot
LABEL dockerhue.lang=go
COPY --from=build /hue /hue
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/hue"]
