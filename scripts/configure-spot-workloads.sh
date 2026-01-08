#!/bin/bash

echo "🎯 Configurando workloads para spot instances"

# Crear deployment que usa spot instances
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spot-workload-example
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spot-workload
  template:
    metadata:
      labels:
        app: spot-workload
    spec:
      # Toleration para spot instances
      tolerations:
      - key: "kubernetes.azure.com/scalesetpriority"
        operator: "Equal"
        value: "spot"
        effect: "NoSchedule"
      
      # Node selector para spot instances
      nodeSelector:
        kubernetes.azure.com/scalesetpriority: "spot"
      
      containers:
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        ports:
        - containerPort: 80
EOF

echo "✅ Workload configurado para spot instances"
echo "💰 Ahorro estimado: 60-90% vs nodos regulares"
