import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:agenpet/services/app_database.dart';

class LogisticaTaxiDogView extends StatefulWidget {
  const LogisticaTaxiDogView({super.key});

  @override
  _LogisticaTaxiDogViewState createState() => _LogisticaTaxiDogViewState();
}

class _LogisticaTaxiDogViewState extends State<LogisticaTaxiDogView> {
  final _db = AppDatabase.instance;
  DateTime _dataSelecionada = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _viagens = [];

  @override
  void initState() {
    super.initState();
    _carregarViagens();
  }

  Future<void> _carregarViagens() async {
    setState(() => _isLoading = true);
    _viagens = [];

    try {
      final startOfDay = DateTime(
        _dataSelecionada.year,
        _dataSelecionada.month,
        _dataSelecionada.day,
        0,
        0,
        0,
      );
      final endOfDay = DateTime(
        _dataSelecionada.year,
        _dataSelecionada.month,
        _dataSelecionada.day,
        23,
        59,
        59,
      );

      // 1. Buscar Agendamentos (Banho/Tosa)
      final agendamentosSnap = await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('agendamentos')
          .where('data_inicio', isGreaterThanOrEqualTo: startOfDay)
          .where('data_inicio', isLessThanOrEqualTo: endOfDay)
          .where('taxi_dog', isEqualTo: true)
          .where('status', isNotEqualTo: 'cancelado')
          .get();

      // 2. Buscar Hotel
      final hotelSnap = await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('reservas_hotel')
          // Hotel pode ter check-in OU check-out no dia. Simplificando para check-in por enquanto.
          // Ideal seria verificar se data selecionada == check_in ou check_out.
          // Por simplicidade, vamos pegar check_in no dia.
          .where('check_in', isGreaterThanOrEqualTo: startOfDay)
          .where('check_in', isLessThanOrEqualTo: endOfDay)
          .where('taxi_dog', isEqualTo: true)
          .where('status', whereIn: ['reservado', 'hospedado'])
          .get();

      // 3. Buscar Creche
      // Creche cria 1 doc por dia
      final crecheSnap = await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('reservas_creche')
          .where('check_in', isGreaterThanOrEqualTo: startOfDay)
          .where('check_in', isLessThanOrEqualTo: endOfDay)
          .where('taxi_dog', isEqualTo: true)
          .where('status', whereIn: ['reservado', 'hospedado'])
          .get();

      // Unificar
      final List<Map<String, dynamic>> lista = [];

      for (var doc in agendamentosSnap.docs) {
        final d = doc.data();
        lista.add({
          'id': doc.id,
          'tipo': 'Banho e Tosa',
          'cliente': d['profissional_nome'] ?? 'Cliente', // Ajuste conforme seu modelo
          'pet': d['pet_nome'] ?? 'Pet',
          'endereco': d['endereco_buscar'] ?? 'Endereço não informado',
          'hora': (d['data_inicio'] as Timestamp).toDate(),
          'modalidade': d['modalidade_taxi'] ?? 'ida_volta',
          'cor': Colors.blue,
          'icon': FontAwesomeIcons.shower,
        });
      }

      for (var doc in hotelSnap.docs) {
        final d = doc.data();
        lista.add({
          'id': doc.id,
          'tipo': 'Hotel',
          'cliente': 'Hóspede',
          'pet': 'Pet Hotel',
          'endereco': d['endereco_buscar'] ?? 'Endereço não informado',
          'hora': (d['check_in'] as Timestamp).toDate(),
          'modalidade': d['modalidade_taxi'] ?? 'ida_volta',
          'cor': Colors.orange,
          'icon': FontAwesomeIcons.hotel,
        });
      }

      for (var doc in crecheSnap.docs) {
        final d = doc.data();
        lista.add({
          'id': doc.id,
          'tipo': 'Creche',
          'cliente': 'Aluno',
          'pet': 'Pet Creche',
          'endereco': d['endereco_buscar'] ?? 'Endereço não informado',
          'hora': (d['check_in'] as Timestamp).toDate(),
          'modalidade': d['modalidade_taxi'] ?? 'ida_volta',
          'cor': Colors.green,
          'icon': FontAwesomeIcons.school,
        });
      }

      // Ordenar por horário
      lista.sort((a, b) => (a['hora'] as DateTime).compareTo(b['hora'] as DateTime));

      if (mounted) {
        setState(() {
          _viagens = lista;
        });
      }
    } catch (e) {
      print("Erro logistica: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _abrirMapa(String endereco) async {
    final query = Uri.encodeComponent(endereco);
    final url = "https://www.google.com/maps/search/?api=1&query=$query";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Não foi possível abrir o mapa.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Logística Táxi Dog",
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A148C),
                      ),
                    ),
                    Text(
                      "Gerencie as rotas de busca e entrega",
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(_dataSelecionada),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.calendar_today, size: 20),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dataSelecionada,
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _dataSelecionada = picked);
                            _carregarViagens();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 30),

            // LISTA
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _viagens.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                FontAwesomeIcons.car,
                                size: 50,
                                color: Colors.grey[300],
                              ),
                              SizedBox(height: 20),
                              Text(
                                "Nenhuma viagem para esta data.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _viagens.length,
                          itemBuilder: (context, index) {
                            final item = _viagens[index];
                            final hora = DateFormat('HH:mm').format(item['hora']);
                            return Card(
                              margin: EdgeInsets.only(bottom: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 2,
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                leading: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: item['cor'].withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(item['icon'], color: item['cor']),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      hora,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${item['pet']} (${item['tipo']})",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            item['endereco'],
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: ElevatedButton.icon(
                                  icon: Icon(Icons.map, size: 16),
                                  label: Text("Abrir Mapa"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[50],
                                    foregroundColor: Colors.blue[700],
                                    elevation: 0,
                                  ),
                                  onPressed: () => _abrirMapa(item['endereco']),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
