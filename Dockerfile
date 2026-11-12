# Start from a small official nginx image (nginx is a web server, alpine is a tiny Linux)
FROM nginx:alpine

# Copy our pre-built React files from the "build" folder from my laptop
# into the folder nginx serves websites from
COPY build/ /usr/share/nginx/html/

# Document that the container listens on port 80 (HTTP)
# (this doesn't open the port by itself; the -p / ports mapping does that)
EXPOSE 80

# Start nginx in the foreground so the container keeps running
CMD ["nginx", "-g", "daemon off;"]