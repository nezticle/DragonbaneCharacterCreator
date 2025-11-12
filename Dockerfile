# Build stage
FROM docker.io/library/swift:6.0-jammy AS builder
WORKDIR /build
COPY . .
RUN swift build --configuration release --product DragonbaneCharacterServer

# Runtime stage
FROM docker.io/library/swift:6.0-jammy AS runtime
WORKDIR /app
COPY --from=builder /build/.build/release/DragonbaneCharacterServer /app/DragonbaneCharacterServer
COPY --from=builder /build/.build/release/DragonbaneCharacterCreator_DragonbaneCharacterServer.resources /app/Resources
COPY --from=builder /build/.build/release/DragonbaneCharacterCreator_DragonbaneCharacterCore.resources /app/DragonbaneCharacterCreator_DragonbaneCharacterCore.resources
ENV PORT=8080
EXPOSE 8080
CMD ["./DragonbaneCharacterServer", "serve", "--hostname", "0.0.0.0", "--port", "8080"]
