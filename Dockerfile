FROM golang:1.15.7-alpine as build

WORKDIR /app

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

COPY ./ ./

RUN go build -o hello-world

FROM scratch

COPY --from=build /app/hello-world ./

ENTRYPOINT ["./hello-world"]
