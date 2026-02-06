// 1. IMPORTAÇÕES GERAIS
const { setGlobalOptions } = require("firebase-functions/v2");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// 2. CONFIGURAÇÃO GLOBAL (Sul do Brasil)
setGlobalOptions({ region: "southamerica-east1" });

// 3. IMPORTAÇÕES DOS CONTROLLERS

// --- NOVOS MÓDULOS (Refatorados) ---
// Certifique-se de que os arquivos agendamento.js, vendas.js e estoque.js
// estão dentro da pasta 'controllers' conforme criamos anteriormente.
const agendamento = require("./controllers/agendamento");
const vendas = require("./controllers/vendas");
const estoque = require("./controllers/estoque");

// --- MÓDULOS EXISTENTES (Mantidos) ---
const hotelController = require("./controllers/hotelController");
const crecheController = require("./controllers/crecheController");
const checkoutsAgenpets = require("./controllers/checkouts_agenpets");
const notificationsApp = require("./controllers/notifications_app");
const notificationsWhatsapp = require("./controllers/notifications_whatsapp");
const adminController = require("./controllers/adminController");
const paymentController = require("./controllers/paymentController");
const adminTenantsController = require("./controllers/adminTenantsController");


// 4. EXPORTAÇÕES (API PUBLICADA)

// MÓDULO DE AGENDAMENTO E VENDAS (Refatorado)

// Agenda
exports.buscarHorarios = agendamento.buscarHorarios;
exports.criarAgendamento = agendamento.criarAgendamento;
exports.salvarChecklistPet = agendamento.salvarChecklistPet;

// Vendas e Assinaturas
// Nota: 'realizarVendaAssinatura' agora vem do módulo 'vendas'
exports.realizarVendaAssinatura = vendas.realizarVendaAssinatura;

// Pagamentos (Pix / Gateway) - Mantido do controller original de pagamentos
exports.comprarAssinatura = paymentController.gerarPixAssinatura;
exports.webhookPix = paymentController.webhookPix;
exports.efipaywebhook = paymentController.efipaywebhook;
exports.webhookMercadoPago = paymentController.webhookMercadoPago;
exports.realizarCheckout = checkoutsAgenpets.realizarCheckout;

// MÓDULO DE ESTOQUE E KARDEX (NOVO - Triggers)

// Estas funções rodam automaticamente quando o banco de dados muda
exports.onVendaCriada = estoque.onVendaCriada;
exports.onMovimentacaoCriada = estoque.onMovimentacaoCriada;

// MÓDULO ADMIN TENANTS (Multi-lojas)

exports.criarTenant = adminTenantsController.criarTenant;
exports.atualizarTenant = adminTenantsController.atualizarTenant;
exports.alternarStatusTenant = adminTenantsController.alternarStatusTenant;
exports.salvarCredenciaisGateway = adminTenantsController.salvarCredenciaisGateway;
exports.verificarLoja = adminTenantsController.verificarLoja;
exports.configurarWebhookEfi = adminTenantsController.configurarWebhookEfi;



// MÓDULO DE HOTELZINHO

exports.reservarHotel = hotelController.reservarHotel;
exports.obterDiasLotados = hotelController.obterDiasLotados;
exports.realizarCheckoutHotel = hotelController.realizarCheckoutHotel;
exports.registrarPagamentoHotel = hotelController.registrarPagamentoHotel;


// MÓDULO DE CRECHE

exports.reservarCreche = crecheController.reservarCreche;
exports.obterDiasLotadosCreche = crecheController.obterDiasLotadosCreche;
exports.obterPrecoCreche = crecheController.obterPrecoCreche;
exports.realizarCheckoutCreche = crecheController.realizarCheckoutCreche;
exports.registrarPagamentoCreche = crecheController.registrarPagamentoCreche;

// MÓDULO DE NOTIFICAÇÕES (Push & WhatsApp)

exports.notificarPetPronto = notificationsApp.notificarPetPronto;
exports.whatsappConfirmacaoAgendamento = notificationsWhatsapp.whatsappConfirmacaoAgendamento;
exports.whatsappPetPronto = notificationsWhatsapp.whatsappPetPronto;


// MÓDULO ADMIN (Profissionais)

exports.criarContaProfissional = adminController.criarContaProfissional;
exports.atualizarContaProfissional = adminController.atualizarContaProfissional;
exports.deletarContaProfissional = adminController.deletarContaProfissional;
exports.deletarContaProfissional = adminController.deletarContaProfissional;
