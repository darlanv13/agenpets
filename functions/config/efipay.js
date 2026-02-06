const path = require('path');

module.exports = {
    sandbox: process.env.EFI_SANDBOX === 'false' ? false : true,
    client_id: process.env.EFI_CLIENT_ID_HOMOLOG,
    client_secret: process.env.EFI_CLIENT_SECRET_HOMOLOG,
    certificate: path.resolve(__dirname, '../certs/producao-644069-agenpets.p12'),
    pem: false,
};
