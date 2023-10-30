local com = import 'lib/commodore.libjsonnet';

local helm = com.inventory().parameters.topolvm.helm_values;
local webhook_enabled = helm.webhook.podMutatingWebhook.enabled || helm.webhook.pvcMutatingWebhook.enabled;

local certificates_file = std.extVar('output_path') + '/certificates.yaml';
local certificates = com.yaml_load_all(certificates_file);

{
  [if webhook_enabled then 'certificates']: [
    cert { spec+: { duration: '8760h0m0s' } }
    for cert in certificates
  ],
}
