sudo docker run -d -e PORT=8080 \
    -p 80:3030 \
    -v "$(pwd)/config":/app/config \
    a-team-radiator
