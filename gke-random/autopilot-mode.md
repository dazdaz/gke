## Use Auopilot mode in GKE Standard clusters - Run any Compute Class in Autopilot mode
Regular Compute Class
```yaml
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
    - name: my-container
      image: "k8s.gcr.io/pause"
  nodeSelector: 
      cloud.google.com/compute-class: autopilot
```

## Use Auopilot mode in GKE Standard clusters - Run any Compute Class in Autopilot mode
```yaml
apiVersion: cloud.google.com/v1
kind: ComputeClass
metadata:
  name: n2-class
spec:
  autopilot:
    enabled: true
  priorities:
  - machineFamily: n2
  activeMigration:
    optimizeRulePriority: true
```

## Using Autopilot mode in GKE Standard clusters - Configured with exec probe timeouts
```yaml
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
    - name: my-container
      image: "k8s.gcr.io/pause"
      livenessProbe:
        exec:
          command:
            - /bin/sh
            - -c
            - "pgrep my-app || exit 1" # Checks if a process named 'my-app' is running
        initialDelaySeconds: 15
        timeoutSeconds: 5
      readinessProbe:
        httpGet: # Using httpGet for a more common readiness check
          path: /healthz # Replace with your application's actual readiness endpoint
          port: 8080    # Replace with your application's actual port
        initialDelaySeconds: 5
        timeoutSeconds: 3
      startupProbe:
        exec:
          command:
            - /bin/sh
            - -c
            - "test -f /tmp/app-started" # Checks for a file created by the app on startup
        initialDelaySeconds: 10
        failureThreshold: 30
        periodSeconds: 10
        timeoutSeconds: 10
  nodeSelector:
    cloud.google.com/compute-class: autopilot
```

* https://cloud.google.com/kubernetes-engine/docs/how-to/autopilot-classes-standard-clusters
* https://medium.com/google-cloud/prepare-your-gke-workloads-for-stricter-exec-probe-timeouts-in-gke-1-35-078a7913ba56
* https://github.com/robusta-dev/krr Kubernetes Resource Recommendations Based on Historical Data
* https://docs.cloud.google.com/kubernetes-engine/docs/how-to/autopilot-gpus
