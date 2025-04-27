## Project Overview

In this project, I provisioned three virtual machines:  

- **Master Node**: Hosts the Kubernetes control plane components.  
- **Worker Node**: Runs the workloads and connects to the master node.  
- **Management Node**: Used for deploying and managing the cluster. It contains:  
  - K3s Ansible playbooks  
  - Helm charts  
  - Kubernetes YAML files  
  - The `kubeconfig` file for cluster administration  

This setup allows centralized management of the Kubernetes cluster from the management node.

## Overview Of Repo
- `k3s-ansible/` for bootstrapping K3s cluster  
- `helm-charts/` for deploying applications like kube-prometheus for monitoring and Loki for logging  
- `kustomize/` for managing app resources including deployments network policies ingress roles rolebindings and more  
- `Cluster-dependency/` for deploying cluster components like Calico and Nginx ingress controller  
- `bash/` scripts including  
  - Backup script running every one minute on master node  
  - ServiceAccount creation script with kubeconfig generation targeting specific namespace and serviceaccount  
- `vagrant/` Vagrantfile for VM provisioning if needed  

## Sample App Overview Architecture

This sample app consists of two primary pods:

- **Mongo Pod**: Running MongoDB database.
- **Node.js Pod**: A Node.js application that connects to the MongoDB database.

When the Node.js app successfully connects to MongoDB, it will display a message on the web page indicating the successful database connection.

## Traffic Flow

The traffic flow for this application is as follows:

1. **App Pods**: The Node.js app and MongoDB run in separate pods.
2. **App Cluster Service**: These pods are exposed through an internal service within the Kubernetes cluster.
3. **App Ingress**: The Kubernetes ingress resource is used to route incoming traffic from external clients to the Node.js app.
4. **LoadBalancer Service**: The ingress is further routed through a LoadBalancer service to distribute traffic effectively.
5. **External LoadBalancer (HAProxy or Nginx)**: Traffic can then be routed to an external load balancer such as HAProxy or Nginx for further distribution, making the app available to external users.

## Architecture

```
[Mongo Pod] <-------> [Node.js Pod]
                |
          [App Cluster Service]
                |
            [App Ingress]
                |
       [LoadBalancer Service]
                |
    [External LoadBalancer (HAProxy/Nginx)]  ( not used yet)
                |
        [User Web Traffic]
```


### Monitoring and Logging
1. Monitoring with Prometheus and grafana
Prometheus collects data from the Kubernetes cluster, including metrics on CPU usage, memory, network traffic, and pod health, which can be queried for alerts or dashboards.
2. Logging with Loki
Loki is used to collect logs from all the pods running in the Kubernetes cluster. It integrates seamlessly with Prometheus and Grafana for a complete monitoring and logging solution.

I add this code to log messages to both the console and Loki for centralized logging.

```
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  defaultMeta: { service: 'mongodb-app' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.timestamp(),
        winston.format.printf(({ timestamp, level, message, ...rest }) => {
          return `${timestamp} ${level}: ${message} ${Object.keys(rest).length ? JSON.stringify(rest) : ''}`;
        })
      )
    }),
    new LokiTransport({
      host: 'http://loki-grafana-loki-query-frontend.loki.svc.cluster.local:3100',
      json: true,
      labels: { app: 'mongodb-app' },
      batching: true,
      interval: 5,
      replaceTimestamp: true,
      onConnectionError: (err) => console.error('Loki connection error:', err)
    })
  ]
});
```
![LOKI](https://github.com/user-attachments/assets/213ab3b2-b866-4f79-9b8a-49c225474e3f)
![Monitoring](https://github.com/user-attachments/assets/7eb32d58-3e8d-4b81-8648-36d5143f8e54)



### Security Setup for the Sample App
This section explains the security configurations implemented for the sample app, including RBAC (Role-Based Access Control) and Network Policies.

1. RBAC Configuration for User
We have defined an RBAC policy for a specific user named sajjad who is only allowed to get and watch pods in the default namespace.
2. Network Policy Between MongoDB and App Pod
We have defined a NetworkPolicy to restrict traffic between the MongoDB Pod and the Node.js App Pod. This ensures that MongoDB can only accept traffic from the Node.js App Pod with the correct label.

### Backup and Restore for Kubernetes Cluster

1. Backup Process
The backup process is handled through a bash script located in the bash directory within the repository. This script is executed on the master node, retrieves the backup from the cluster, and schedules regular backups.
Backup Details:
- The script is responsible for initiating and automating the backup process.
- The cluster data for K3s is stored at the following path: ``` /var/lib/rancher/k3s/server/db/state.db ```
  
2. Restore Process
The restoration process involves copying the backed-up file to the appropriate location on the Kubernetes master node.
Restore Details:
- To restore the cluster state copy the backup file to the following path: ``` /var/lib/rancher/k3s/server/db/state.db ```
  Once the file is copied, restart the K3s service to apply the changes and restore the cluster to its previous state.


### High Availability and Autoscaling
In our setup, we use Horizontal Pod Autoscaling (HPA) to ensure high availability and efficient resource usage based on the pod's resource utilization. The HPA automatically adjusts the number of pod replicas to maintain optimal resource usage.
The scaling is based on two main resource metrics:
- CPU Usage
- Memory Usage

**HPA Configuration**
The HPA is configured to scale the my-app deployment based on CPU and memory utilization. If the usage exceeds 50% of the defined resource request limits for CPU or memory, the HPA will trigger a scaling event to add more pods.
``` my-app-hpa   Deployment/my-app   cpu: 15%/50%, memory: 16%/50%   1         10        2          4m54s ```

### Conclusion

This setup represents a sample environment running on a local machine (laptop). While this configuration provides a solid foundation for understanding key concepts like autoscaling, monitoring, and centralized logging, there is much more that can be done in a production-grade environment. :slightly_smiling_face:


![Endresult](https://github.com/user-attachments/assets/3646720b-78c7-4263-b9f0-c7bcc22d1922)


