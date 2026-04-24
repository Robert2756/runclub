import 'package:flutter/material.dart';

class FormControls{
  Widget buildSwitch({
    required bool value,
    required ValueChanged<bool> onChanged, // <-- callback to return the bool
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      value: value,
      onChanged: onChanged, // whenever user toggles, bool is sent here
      thumbColor: WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
          ? const Color.fromARGB(255, 223, 186, 255)
          : Colors.grey.shade300;
        }),
      trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
    );
  }
}