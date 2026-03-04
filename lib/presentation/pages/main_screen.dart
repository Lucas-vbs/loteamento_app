import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:loteamento_app/data/models/lot_model.dart';
import 'package:loteamento_app/presentation/providers/lot_provider.dart';
import 'package:loteamento_app/presentation/pages/loading_screen.dart';
import 'package:loteamento_app/presentation/pages/error_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LotProvider>().fetchLots();
    });
  }

  void _handleTap(Offset localOffset, BuildContext context) {
    final provider = context.read<LotProvider>();
    if (!provider.isAdmin) return;

    // Get the actual size of the image to calculate percentages correctly
    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final x = (localOffset.dx / size.width) * 100;
    final y = (localOffset.dy / size.height) * 100;

    debugPrint('--- LOCALIZAÇÃO TOCADA ---');
    debugPrint('X: $x%, Y: $y% (Baseado no tamanho da imagem: ${size.width}x${size.height})');
    debugPrint('Configuração para CSV: ,$x,$y');
    debugPrint('-------------------------');

    _showPlaceLotPicker(x, y);
  }

  void _showPlaceLotPicker(double x, double y) {
    final provider = context.read<LotProvider>();
    final unplaced = provider.unplacedLots;

    if (unplaced.isEmpty) {
      final total = provider.lots.length;
      final msg = total == 0
          ? 'Nenhum lote carregado do CSV. Verifique o arquivo.'
          : 'Todos os $total lotes já possuem pinos vinculados.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular Lote ao Mapa'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: unplaced.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final lot = unplaced[index];
              return ListTile(
                title: Text(
                  'Lote ${lot.lotNumber} - Quadra ${lot.blockNumber}',
                ),
                subtitle: Text('Matrícula: ${lot.matricula}'),
                onTap: () {
                  debugPrint('--- VINCULANDO LOTE ---');
                  debugPrint('Matrícula: ${lot.matricula}');
                  debugPrint(
                    'Lote: ${lot.lotNumber} Quada: ${lot.blockNumber}',
                  );
                  debugPrint('Coordenadas: x=$x, y=$y');
                  debugPrint('COPIE PARA O CSV: ${lot.matricula} ... ,$x,$y');
                  debugPrint('----------------------');

                  provider.placeLot(lot.matricula, x, y);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loteamento Interativo'),
        actions: [
          Consumer<LotProvider>(
            builder: (context, provider, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    provider.isAdmin
                        ? Icons.admin_panel_settings
                        : Icons.person,
                  ),
                  onPressed: () => _toggleAdminMode(provider),
                  tooltip: provider.isAdmin
                      ? 'Modo Admin Ativo'
                      : 'Entrar como Admin',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => provider.fetchLots(),
                  tooltip: 'Recarregar Dados',
                ),
                if (provider.isAdmin)
                   IconButton(
                    icon: const Icon(Icons.bug_report),
                    onPressed: () => _showDebugData(context, provider),
                    tooltip: 'Ver Dados Carregados',
                  ),
                if (provider.isAdmin)
                  IconButton(
                    icon: const Icon(Icons.restore),
                    onPressed: () => _confirmReset(context, provider),
                    tooltip: 'Resetar para Padrão (Limpar Cache)',
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Consumer<LotProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) return const LoadingScreen();
          if (provider.error != null) {
            return ErrorScreen(
              message: provider.error!,
              onRetry: () => provider.fetchLots(),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.1,
                maxScale: 10.0,
                boundaryMargin: const EdgeInsets.all(2000.0),
                clipBehavior: Clip.none,
                child: Center(
                  child: IntrinsicWidth(
                    child: IntrinsicHeight(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTapDown: (details) =>
                                _handleTap(details.localPosition, context),
                            child: Image.asset(
                              'assets/images/map.png',
                              key: _imageKey,
                              fit: BoxFit.none, // Use natural image size
                            ),
                          ),
                          // Use a Postioned.fill with another LayoutBuilder to get the EXACT image size
                          // for the pins, ensuring they are always perfectly aligned with the image pixels.
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, mapConstraints) {
                                return Stack(
                                  children: provider.placedLots.map(
                                    (lot) => _buildPin(lot, mapConstraints, provider.isAdmin),
                                  ).toList(),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPin(LotModel lot, BoxConstraints constraints, bool isAdmin) {
    // Make pins larger on mobile for easier tapping
    final isMobile = constraints.maxWidth < 600;
    final pinSize = isMobile ? 32.0 : 20.0;
    // Calculate position based on percentage
    final left = (lot.x / 100) * constraints.maxWidth - (pinSize / 2);
    final top = (lot.y / 100) * constraints.maxHeight - (pinSize / 2);

    Widget pin = Container(
      width: pinSize,
      height: pinSize,
      decoration: BoxDecoration(
        color: lot.status.color.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          lot.lotNumber,
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 12 : 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    if (isAdmin) {
      return Positioned(
        left: left,
        top: top,
        child: Draggable(
          feedback: Opacity(opacity: 0.5, child: pin),
          childWhenDragging: Container(),
          onDragEnd: (details) {
            // Calculate new position relative to the image container
            final RenderBox? renderBox =
                _imageKey.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox == null) return;
            
            final localOffset = renderBox.globalToLocal(details.offset);
            final size = renderBox.size;

            final newX = (localOffset.dx / size.width) * 100;
            final newY = (localOffset.dy / size.height) * 100;

            debugPrint('--- PINO MOVIDO (${lot.matricula}) ---');
            debugPrint('Novos valores para o CSV: ,$newX,$newY');
            debugPrint('------------------------------------');

            context.read<LotProvider>().updateLotPosition(lot.id, newX, newY);
          },
          child: GestureDetector(onTap: () => _showLotDetails(lot), child: pin),
        ),
      );
    }

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(onTap: () => _showLotDetails(lot), child: pin),
    );
  }

  void _toggleAdminMode(LotProvider provider) {
    if (provider.isAdmin) {
      provider.setAdmin(false);
    } else {
      _showAdminLogin(provider);
    }
  }

  void _showAdminLogin(LotProvider provider) {
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acesso Administrativo'),
        content: TextField(
          controller: passController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Senha'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // Password check from .env
              final correctPassword =
                  dotenv.env['ADMIN_PASSWORD'] ?? 'admin_lote_2026';
              if (passController.text == correctPassword) {
                provider.setAdmin(true);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Senha incorreta')),
                );
              }
            },
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, LotProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetar Dados?'),
        content: const Text(
          'Isso irá apagar as alterações salvas no navegador e recarregar o arquivo CSV original dos assets. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              provider.resetData();
              Navigator.pop(context);
            },
            child: const Text('Resetar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDebugData(BuildContext context, LotProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('DEBUG: ${provider.lots.length} Lotes'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total: ${provider.lots.length}'),
              Text('Vinculados: ${provider.placedLots.length}'),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  itemCount: provider.lots.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final lot = provider.lots[index];
                    return ListTile(
                      dense: true,
                      title: Text('Matrícula: ${lot.matricula}'),
                      subtitle: Text(
                        'Coord: [${lot.x}, ${lot.y}] | Location: ${lot.hasLocation}',
                        style: TextStyle(
                          color: lot.hasLocation ? Colors.green : Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _showLotDetails(LotModel lot) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final provider = context.read<LotProvider>();
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lote ${lot.lotNumber}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: lot.status.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: lot.status.color),
                    ),
                    child: Text(
                      lot.status.label,
                      style: TextStyle(
                        color: lot.status.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _detailRow(
                Icons.person_outline,
                'Proprietário',
                lot.proprietario,
              ),
              _detailRow(Icons.description, 'Matrícula', lot.matricula),
              _detailRow(Icons.grid_view, 'Quadra', lot.blockNumber),
              _detailRow(Icons.square_foot, 'Área', '${lot.area} m²'),
              _detailRow(
                Icons.payments,
                'Preço',
                'R\$ ${lot.price.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 24),
              // if (provider.isAdmin) ...[
              //   SizedBox(
              //     width: double.infinity,
              //     height: 50,
              //     child: OutlinedButton.icon(
              //       style: OutlinedButton.styleFrom(
              //         foregroundColor: Colors.red,
              //         side: const BorderSide(color: Colors.red),
              //         shape: RoundedRectangleBorder(
              //           borderRadius: BorderRadius.circular(12),
              //         ),
              //       ),
              //       onPressed: () async {
              //         final confirm = await showDialog<bool>(
              //           context: context,
              //           builder: (context) => AlertDialog(
              //             title: const Text('Remover Pin'),
              //             content: const Text(
              //               'Deseja realmente remover este lote do mapa? Ele voltará para a lista de não vinculados.',
              //             ),
              //             actions: [
              //               TextButton(
              //                 onPressed: () => Navigator.pop(context, false),
              //                 child: const Text('Cancelar'),
              //               ),
              //               TextButton(
              //                 onPressed: () => Navigator.pop(context, true),
              //                 child: const Text(
              //                   'Remover',
              //                   style: TextStyle(color: Colors.red),
              //                 ),
              //               ),
              //             ],
              //           ),
              //         );
              //         if (confirm == true) {
              //           await provider.removePin(lot.id);
              //           if (context.mounted) Navigator.pop(context);
              //         }
              //       },
              //       icon: const Icon(Icons.location_off),
              //       label: const Text('Remover Pin / Realocar'),
              //     ),
              //   ),
              //   const SizedBox(height: 12),
              // ],
              SizedBox(
                width: double.infinity,
                height: 30,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
