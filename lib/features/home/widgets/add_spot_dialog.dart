import 'package:flutter/material.dart';
import 'package:roamly/models/location_model.dart';

class AddSpotDialog extends StatefulWidget {
  final double currentLat;
  final double currentLng;

  const AddSpotDialog({
    super.key,
    required this.currentLat,
    required this.currentLng,
  });

  @override
  State<AddSpotDialog> createState() => _AddSpotDialogState();
}

class _AddSpotDialogState extends State<AddSpotDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _urlController = TextEditingController();
  double _rating = 3.0;
  LocationType _selectedType = LocationType.generated;

  // Map icons to location types for the dropdown
  final Map<LocationType, IconData> _typeIcons = {
    LocationType.generated: Icons.place,
    LocationType.favorite: Icons.favorite,
    LocationType.scenic: Icons.landscape,
    LocationType.visited: Icons.beenhere,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_location_alt, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('Mark New Spot'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.currentLat.toStringAsFixed(4)}, ${widget.currentLng.toStringAsFixed(4)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Spot Name',
                    hintText: 'e.g., Central Park',
                    prefixIcon: Icon(Icons.label_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter a name'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<LocationType>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: LocationType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(_typeIcons[type] ?? Icons.place, size: 18),
                          const SizedBox(width: 8),
                          Text(type.name.toUpperCase()),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What makes this spot special?',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (Optional)',
                    hintText: 'https://example.com/image.jpg',
                    prefixIcon: Icon(Icons.image_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Rating', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    Text(
                      _rating.toString(),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _rating,
                        min: 1,
                        max: 5,
                        divisions: 8,
                        label: _rating.toString(),
                        onChanged: (val) => setState(() => _rating = val),
                      ),
                    ),
                    const Icon(Icons.star, color: Colors.amber),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final newLocation = LocationModel(
                name: _nameController.text,
                description: _descController.text,
                latitude: widget.currentLat,
                longitude: widget.currentLng,
                imageUrl: _urlController.text.isNotEmpty
                    ? _urlController.text
                    : null,
                rating: _rating,
                type: _selectedType,
                createdAt: DateTime.now(),
              );
              Navigator.pop(context, newLocation);
            }
          },
          icon: const Icon(Icons.check),
          label: const Text('Add Spot'),
        ),
      ],
    );
  }
}
