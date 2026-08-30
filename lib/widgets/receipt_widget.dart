import 'package:flutter/material.dart';
import '../models/receipt.dart';
import '../utils/currency_formatter.dart';
import 'dashed_line.dart';

class ReceiptWidget extends StatelessWidget {
  final Receipt receipt;
  final String headerText;
  final String footerText;
  final bool showLogo;
  final double horizontalPadding;
  final String imagePath;

  const ReceiptWidget({
    super.key,
    required this.receipt,
    required this.headerText,
    required this.footerText,
    this.showLogo = true,
    this.horizontalPadding = 0,
    this.imagePath = 'assets/images/logonota.png',
  });

  @override
  Widget build(BuildContext context) {
    // Kunci ukuran mutlak untuk printer 58mm (rata-rata 384 pixels width area cetak)
    return Container(
      width: 384,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16), // Padding internal nota
      color: Colors.white, // Kertas putih
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 0. Logo (opsional)
          if (showLogo) ...([
            Image.asset(
              imagePath,
              width: 384,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
          ]),

          // 1. Header
          Text(
            headerText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          // 2. Info Transaksi (Tanggal & No)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                receipt.formattedDate,
                style: const TextStyle(fontSize: 18, color: Colors.black),
              ),
              Text(
                receipt.receiptNumber,
                style: const TextStyle(fontSize: 18, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. Garis Putus-putus
          const DashedLine(),
          const SizedBox(height: 8),

          // 4. Daftar Barang
          ...receipt.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: const TextStyle(fontSize: 21, color: Colors.black),
                        ),
                        Text(
                          '${item.quantity} x ${CurrencyFormatter.formatRupiah(item.product.price)}',
                          style: const TextStyle(fontSize: 19, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.formatRupiah(item.subtotal),
                    style: const TextStyle(fontSize: 21, color: Colors.black),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 4),

          // Label DISCOUNT (tampil sebelum garis pemisah, jika ada diskon)
          if (receipt.discountPercent > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DISCOUNT ${receipt.discountPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 21, color: Colors.black),
                ),
                Text(
                  '- ${CurrencyFormatter.formatRupiah(receipt.discountAmount)}',
                  style: const TextStyle(fontSize: 21, color: Colors.black),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          // 5. Garis Putus-putus
          const DashedLine(),
          const SizedBox(height: 8),

          // 6. Harga dicoret (jika ada diskon) + TOTAL
          if (receipt.discountPercent > 0) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                CurrencyFormatter.formatRupiah(receipt.subtotalBeforeDiscount),
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              Text(
                CurrencyFormatter.formatRupiah(receipt.total),
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 7. Footer
          Text(
            footerText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, color: Colors.black),
          ),
          const SizedBox(height: 16), // Ruang ekstra di bawah untuk area pemotongan kertas
        ],
      ),
    );
  }
}
