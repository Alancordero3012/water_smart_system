import 'package:flutter/material.dart';
import '../../shared/glass_container.dart';

class CostSavingsWidget extends StatelessWidget {
  const CostSavingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Calculation
    // Assumed cost: $1.50 USD per m3 (1000 Liters)
    // Assumed saved: 350 Liters this month
    const double pricePerLiter = 1.50 / 1000;
    const double savedLiters = 350;
    final double moneySaved = savedLiters * pricePerLiter;

    return GlassContainer(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent,
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Icon(Icons.savings, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ahorro Estimado (Mes)',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${moneySaved.toStringAsFixed(2)} USD',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${savedLiters.toInt()} Litros de lluvia usados',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
