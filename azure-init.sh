#!/bin/sh

MODEL=$1
TOKEN=$2

docker pull anyscale/ray-llm

mkdir data
chmod 777 data

cat > data/init.sh << EOM
#!/bin/bash

export HUGGING_FACE_HUB_TOKEN=${TOKEN}
CPUCOUNT=$(($(nproc) - 3))
sed -i "s/num_cpus_per_worker: .*/num_cpus_per_worker: \${CPUCOUNT}/" /home/ray/models/continuous_batching/${MODEL}.yaml

ray start --resources '{"accelerator_type_a10":1}' --head

serve run --host 0.0.0.0 /data/serve.yaml

EOM

cat > data/serve.yaml << EOM
applications:
- name: ray-llm
  route_prefix: /
  import_path: rayllm.backend:router_application
  args:
    models:
      - "/home/ray/models/continuous_batching/${MODEL}.yaml"

EOM

docker run -d --gpus all --shm-size 10g -p 8080:8000 -e HF_HOME=/data --restart=always -v $(pwd)/data:/data anyscale/ray-llm:latest bash /data/init.sh
