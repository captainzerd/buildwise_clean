class Phase {
  final String id;
  final String name;
  const Phase({required this.id, required this.name});

  static const defaults = <Phase>[
    Phase(id: 'foundation', name: 'Foundation'),
    Phase(id: 'superstructure', name: 'Superstructure'),
    Phase(id: 'roofing', name: 'Roofing'),
    Phase(id: 'mep', name: 'MEP'),
    Phase(id: 'finishing', name: 'Finishing'),
    Phase(id: 'external', name: 'External Works'),
  ];
}
