// 1. IMPORTAÇÕES
const {setGlobalOptions} = require("firebase-functions/v2");
const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// 2. CONFIGURAÇÃO GLOBAL (Sul do Brasil)
setGlobalOptions({region: "southamerica-east1"});

// 3. IMPORTAÇÕES DOS CONTROLLERS
const agendamentoController = require("./controllers/agendamentoController");
const hotelController = require("./controllers/hotelController");
const crecheController = require("./controllers/crecheController");
const checkoutsAgenpets = require("./controllers/checkouts_agenpets");
const notificationsApp = require("./controllers/notifications_app");
const notificationsWhatsapp = require("./controllers/notifications_whatsapp");
const adminController = require("./controllers/adminController");
const paymentController = require("./controllers/paymentController");
const adminTenantsController = require("./controllers/adminTenantsController");

// 4. EXPORTAÇÕES (O que o Firebase vai enxergar)

// --- Módulo de Agendamento ---
exports.buscarHorarios = agendamentoController.buscarHorarios;
exports.criarAgendamento = agendamentoController.criarAgendamento;
// Atualizado para usar o novo controller de pagamentos
exports.comprarAssinatura = paymentController.gerarPixAssinatura;
exports.webhookPix = paymentController.webhookPix;

// --- Módulo Admin Tenants ---
exports.testarCredenciaisGateway = adminTenantsController.testarCredenciaisGateway;
exports.criarTenant = adminTenantsController.criarTenant;
exports.atualizarTenant = adminTenantsController.atualizarTenant;
exports.alternarStatusTenant = adminTenantsController.alternarStatusTenant;

exports.realizarCheckout = checkoutsAgenpets.realizarCheckout;
exports.realizarVendaAssinatura = agendamentoController.realizarVendaAssinatura;

// --- Módulo de Hotelzinho ---
exports.reservarHotel = hotelController.reservarHotel;
exports.obterDiasLotados = hotelController.obterDiasLotados;
exports.realizarCheckoutHotel = hotelController.realizarCheckoutHotel;
exports.registrarPagamentoHotel = hotelController.registrarPagamentoHotel;

// --- Módulo de Creche ---
exports.reservarCreche = crecheController.reservarCreche;
exports.obterDiasLotadosCreche = crecheController.obterDiasLotadosCreche;
exports.obterPrecoCreche = crecheController.obterPrecoCreche;
exports.realizarCheckoutCreche = crecheController.realizarCheckoutCreche;
exports.registrarPagamentoCreche = crecheController.registrarPagamentoCreche;

// --- Módulo de Notificações ---
exports.notificarPetPronto = notificationsApp.notificarPetPronto;

// --- Módulo de Notificações (WhatsApp) ---
exports.whatsappConfirmacaoAgendamento = notificationsWhatsapp.whatsappConfirmacaoAgendamento;
exports.whatsappPetPronto = notificationsWhatsapp.whatsappPetPronto;

// --- Salvar CheckList ---
exports.salvarChecklistPet = agendamentoController.salvarChecklistPet;

// --- Módulo Admin ---
exports.criarContaProfissional = adminController.criarContaProfissional;
