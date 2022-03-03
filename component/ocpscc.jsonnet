// instance-specific security context constraint object for openshift
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.topolvm;

local isOpenshift = std.startsWith(inv.parameters.facts.distribution, 'openshift');
local instance = inv.parameters._instance;

local openshiftScc = {
  apiVersion: 'security.openshift.io/v1',
  kind: 'SecurityContextConstraints',
  metadata: {
    name: 'topolvm-scc',
    namespace: params.namespace,
    labels: {
      'app.kubernetes.io/name': 'topolvm',
      'app.kubernetes.io/component': 'topolvm',
      'app.kubernetes.io/managed-by': 'syn',
    },
  },
  users: [
    'system:serviceaccount:' + params.namespace + ':topolvm-controller',
    'system:serviceaccount:' + params.namespace + ':topolvm-scheduler',
    'system:serviceaccount:' + params.namespace + ':topolvm-node',
    'system:serviceaccount:' + params.namespace + ':topolvm-lvmd',
    'system:serviceaccount:' + params.namespace + ':topolvm-kubescheduler',
  ],
  volumes: [
    '*',
  ],
  allowHostDirVolumePlugin: true,
  allowHostIPC: true,
  allowHostNetwork: true,
  allowHostPID: true,
  allowHostPorts: true,
  allowPrivilegeEscalation: true,
  allowPrivilegedContainer: true,
  allowedCapabilities: [
    '*',
  ],
  allowedUnsafeSysctls: [
    '*',
  ],
  defaultAddCapabilities: null,
  fsGroup: {
    type: 'RunAsAny',
  },
  priority: null,
  runAsUser: {
    type: 'RunAsAny',
  },
  seLinuxContext: {
    type: 'RunAsAny',
  },
  seccompProfiles: [
    '*',
  ],
  supplementalGroups: {
    type: 'RunAsAny',
  },
  readOnlyRootFilesystem: false,
  requiredDropCapabilities: null,
};

// Define outputs below
{
  [if isOpenshift then '01_openshift-scc']: openshiftScc,
}
