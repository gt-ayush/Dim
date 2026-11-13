IMAGE_NAME := kde-headless
CONTAINER_NAME := kde-headless
SSH_PORT := 2222
VNC_PORT := 5900
NOVNC_PORT := 6080

.PHONY: build run stop logs shell clean

build:
	podman build -t $(IMAGE_NAME) -f Containerfile .

run:
	podman run -d --rm \
		--name $(CONTAINER_NAME) \
		-p $(SSH_PORT):22 \
		-p $(VNC_PORT):5900 \
		-p $(NOVNC_PORT):6080 \
		--shm-size=512m \
		$(IMAGE_NAME)

stop:
	-podman stop $(CONTAINER_NAME)

logs:
	podman logs -f $(CONTAINER_NAME)

shell:
	podman exec -it $(CONTAINER_NAME) /bin/bash

clean: stop
	-podman rmi $(IMAGE_NAME)
