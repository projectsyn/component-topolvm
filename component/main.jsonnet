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
