// main template for topolvm
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local sc = import 'lib/storageclass.libsonnet';
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
      // Configure the namespaces so that the OCP4 cluster-monitoring
      // Prometheus can find the servicemonitors and rules.
      'openshift.io/cluster-monitoring': 'true',
    },
  },
};

local StorageClass(name='ssd-local') = sc.storageClass(name) {
  metadata+: {
    labels+: {
      'app.kubernetes.io/name': 'topolvm',
      'app.kubernetes.io/instance': 'topolvm',
    },
  },
  allowVolumeExpansion: params.storageclasses[name].volumeexpansion,
  parameters: {
    'csi.storage.k8s.io/fstype': params.storageclasses[name].fstype,
    [if params.helm_values.useLegacy then 'topolvm.cybozu.com/device-class' else 'topolvm.io/device-class']: params.storageclasses[name].class,
  },
  provisioner: if params.helm_values.useLegacy then 'topolvm.cybozu.com' else 'topolvm.io',
  volumeBindingMode: 'WaitForFirstConsumer',
  [if std.objectHas(params.storageclasses[name], 'retainpolicy') then 'reclaimPolicy']: params.storageclasses[name].retainpolicy,
};

// Define outputs below
{
  '00_namespace': namespace,
  '22_storage_classes': [
    StorageClass(name)
    for name in std.objectFields(params.storageclasses)
  ],
}
