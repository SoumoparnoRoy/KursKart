import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/providers/auth_provider.dart';
import 'package:kurskart/providers/cart_provider.dart';
import 'package:kurskart/providers/navigation_provider.dart';
import 'package:kurskart/views/screens/cart_tab.dart';
import 'package:kurskart/views/screens/home_tab.dart';
import 'package:kurskart/views/screens/orders_tab.dart';

/// The shell a signed-in user lands in.
class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  static const _activeColor = Color.fromARGB(255, 0, 47, 255);
  static const _inactiveColor = Colors.grey;

  // Material icons rather than the PNG assets: they ship outlined/filled pairs,
  // which gives a real inactive/active state per tab. Tinting the PNGs was the
  // alternative, but orders.png and history.png carry a faint opaque background
  // that tints to a solid block, and no icon in the clean 120px set fits Orders.
  static const _tabs = <_TabSpec>[
    _TabSpec(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    _TabSpec(
      label: 'Cart',
      icon: Icons.shopping_cart_outlined,
      activeIcon: Icons.shopping_cart,
    ),
    _TabSpec(
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
    ),
    _TabSpec(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  Widget _maybeBadge(WidgetRef ref, int index, Widget icon) {
    if (index != Tabs.cart) return icon;

    final count = ref.watch(cartProvider).value?.itemCount ?? 0;
    if (count == 0) return icon;

    return Badge(
      label: Text('$count'),
      backgroundColor: _activeColor,
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final currentIndex = ref.watch(selectedTabProvider);

    return Scaffold(
      body: SafeArea(
        child: switch (currentIndex) {
          0 => const HomeTab(),
          1 => const CartTab(),
          2 => const OrdersTab(),
          3 => _ProfileTab(
            fullName: user?.fullName ?? '',
            email: user?.email ?? '',
          ),
          _ => _PlaceholderTab(label: _tabs[currentIndex].label),
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) =>
            ref.read(selectedTabProvider.notifier).state = index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _activeColor,
        unselectedItemColor: _inactiveColor,
        selectedLabelStyle: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.nunitoSans(),
        items: [
          for (final (index, tab) in _tabs.indexed)
            BottomNavigationBarItem(
              // Only the Cart tab carries a count.
              icon: _maybeBadge(ref, index, Icon(tab.icon)),
              activeIcon: _maybeBadge(ref, index, Icon(tab.activeIcon)),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$label coming soon',
        style: GoogleFonts.lato(fontSize: 18, color: Colors.black54),
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.fullName, required this.email});

  final String fullName;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icons/user.png', width: 72, height: 72),
            const SizedBox(height: 16),
            Text(
              fullName,
              style: GoogleFonts.lato(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: GoogleFonts.nunitoSans(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              icon: Image.asset('assets/icons/logout.png', width: 20, height: 20),
              label: Text(
                'Sign Out',
                style: GoogleFonts.lato(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
