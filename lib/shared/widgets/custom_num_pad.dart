import 'package:flutter/material.dart';

/// A large, touch-friendly numeric keypad grid for rapid data entry.
///
/// Emits entered digits through [onDigitPressed], deletes through
/// [onBackspacePressed], and clears through [onClearPressed].
class CustomNumPad extends StatelessWidget {
  final Function(String digit) onDigitPressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback onClearPressed;

  const CustomNumPad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    required this.onClearPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padHeight = MediaQuery.of(context).size.height * 0.4;

    return SizedBox(
      height: padHeight,
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.6,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          _buildDigitButton('1', theme),
          _buildDigitButton('2', theme),
          _buildDigitButton('3', theme),
          _buildDigitButton('4', theme),
          _buildDigitButton('5', theme),
          _buildDigitButton('6', theme),
          _buildDigitButton('7', theme),
          _buildDigitButton('8', theme),
          _buildDigitButton('9', theme),
          _buildClearButton(theme),
          _buildDigitButton('0', theme),
          _buildBackspaceButton(theme),
        ],
      ),
    );
  }

  Widget _buildDigitButton(String digit, ThemeData theme) {
    return ElevatedButton(
      onPressed: () => onDigitPressed(digit),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        textStyle: theme.textTheme.headlineMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(digit),
    );
  }

  Widget _buildBackspaceButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: onBackspacePressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.errorContainer,
        foregroundColor: theme.colorScheme.onErrorContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Icon(Icons.backspace_outlined),
    );
  }

  Widget _buildClearButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: onClearPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.tertiaryContainer,
        foregroundColor: theme.colorScheme.onTertiaryContainer,
        textStyle: theme.textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text('C'),
    );
  }
}