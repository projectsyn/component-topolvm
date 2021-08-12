// main template for topolvm
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.topolvm;

local namespace = kube.Namespace(params.namespace) {
  metadata+: {
    annotations+: {
      'openshift.io/node-selector': '',
    },
    labels+: {
      'app.kubernetes.io/name': params.namespace,
      'topolvm.cybozu.com/webhook': 'ignore',
    },
  },
};

local lvmd_configmap = kube.ConfigMap('topolvm-lvmd0') {
  metadata+: {
    labels+: {
      idx: '0',
      'app.kubernetes.io/name': 'topolvm',
      'app.kubernetes.io/instance': 'topolvm',
      'app.kubernetes.io/version': '0.8.3',
    },
  },
  data: {
    'lvmd.yaml': |||
      socket-name: /run/topolvm/lvmd.sock
      device-classes:
      - name: %(name)s
        default: %(default)s
        spare-gb: %(sparegb)d
        volume-group: %(volumegroup)s
    ||| % {
      name: params.deviceclasses[0].name,
      default: 'true',
      sparegb: params.deviceclasses[0].sparegb,
      volumegroup: params.deviceclasses[0].volumegroup,
    },
  },
};

local lvmd_daemonset = kube.DaemonSet('topolvm-lvmd0') {
  metadata+: {
    labels+: {
      idx: '0',
      'app.kubernetes.io/name': 'topolvm',
      'app.kubernetes.io/instance': 'topolvm',
      'app.kubernetes.io/version': params.helmValues.image.tag,
    },
  },
  spec: {
    selector: {
      matchLabels: {
        idx: '0',
        'app.kubernetes.io/name': 'topolvm-lvmd0',
      },
    },
    template: {
      metadata: {
        labels: {
          idx: '0',
          'app.kubernetes.io/name': 'topolvm-lvmd0',
        },
        annotations: {
          'prometheus.io/port': '8080',
        },
      },
      spec: {
        serviceAccountName: 'topolvm-lvmd',
        hostPID: true,
        containers: [
          {
            name: 'lvmd',
            image: params.helmValues.image.repository + ':' + params.helmValues.image.tag,
            securityContext: {
              privileged: true,
            },
            command: [
              '/lvmd',
              '--container',
            ],
            resources: {
              limits: {
                cpu: params.resources.lvmd.limits.cpu,
                memory: params.resources.lvmd.limits.memory,
              },
              requests: {
                cpu: params.resources.lvmd.requests.cpu,
                memory: params.resources.lvmd.requests.memory,
              },
            },
            volumeMounts: [
              {
                name: 'lvmd-socket-dir',
                mountPath: '/run/topolvm',
              },
              {
                name: 'config',
                mountPath: '/etc/topolvm',
              },
            ],
          },
        ],
        volumes: [
          {
            name: 'config',
            configMap: {
              name: 'topolvm-lvmd0',
            },
          },
          {
            name: 'lvmd-socket-dir',
            hostPath: {
              path: '/run/topolvm',
              type: 'DirectoryOrCreate',
            },
          },
        ],
        nodeSelector: {
          'syn.tools/topolvm': '',
        },
      },
    },
  },
};

local PriorityClass(name='topolvm') = {
  apiVersion: 'scheduling.k8s.io/v1',
  kind: 'PriorityClass',
  metadata: {
    name: name,
  },
  value: 1000000,
  globalDefault: false,
  description: 'Pods using TopoLVM volumes should use this class.',
};

// Define outputs below
{
  '00_namespace': namespace,
  '11_lvmd_configmap': lvmd_configmap,
  '12_lvmd_daemonset': lvmd_daemonset,
  '21_priority_class': PriorityClass(),
}
