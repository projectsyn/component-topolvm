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

local lvmd_config = {
  'socket-name': '/run/topolvm/lvmd.sock',
  'device-classes': [
    params.deviceclasses[name] { name: name }
    for name in std.objectFields(params.deviceclasses)
  ],
};

local lvmd_configmap = kube.ConfigMap('topolvm-lvmd0') {
  metadata+: {
    labels+: {
      idx: '0',
      'app.kubernetes.io/name': 'topolvm',
      'app.kubernetes.io/instance': 'topolvm',
      'app.kubernetes.io/version': params.images.topolvm.tag,
    },
  },
  data: {
    'lvmd.yaml': std.manifestYamlDoc(lvmd_config),
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
            image: params.images.topolvm.registry + '/' + params.images.topolvm.repository + ':' + params.images.topolvm.tag,
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

local StorageClass(name='ssd-local') = kube.StorageClass(name) {
  metadata+: {
    labels+: {
      'app.kubernetes.io/name': 'topolvm',
      'app.kubernetes.io/instance': 'topolvm',
      'app.kubernetes.io/version': params.images.topolvm.tag,
    },
  },
  allowVolumeExpansion: params.storageclasses[name].volumeexpansion,
  parameters: {
    'csi.storage.k8s.io/fstype': params.storageclasses[name].fstype,
    'topolvm.cybozu.com/device-class': params.storageclasses[name].class,
  },
  provisioner: 'topolvm.cybozu.com',
  volumeBindingMode: 'WaitForFirstConsumer',
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
  '22_storage_classes': [
    StorageClass(name)
    for name in std.objectFields(params.storageclasses)
  ],
}
