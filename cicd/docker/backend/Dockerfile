# 后端微服务通用运行时镜像（与 CPU 架构无关，JAR 由构建上下文以 app.jar 注入）
# 基础镜像使用国外原版：Eclipse Temurin 17 JRE（官方、多架构 amd64/arm64）
FROM eclipse-temurin:17-jre

WORKDIR /app

COPY app.jar app.jar

# JAVA_OPTS 由 compose / k8s 注入（Nacos 地址、激活 profile 等）
ENV JAVA_OPTS=""

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
