const Map<String, List<String>> exerciseAliases = {
  // Press banca / Bench press
  'press banca': ['bench press', 'barbell bench press'],
  'bench press': ['press banca'],
  'press de banca': ['bench press'],

  // Dominadas / Pull ups
  'dominadas': ['pull up', 'pull-up', 'chin up'],
  'pull up': ['dominadas'],
  'pull-up': ['dominadas'],
  'chin up': ['dominadas'],

  // Jalón / Pulldown
  'jalon': ['pulldown', 'lat pulldown', 'lat pulldowns'],
  'jalon al pecho': ['lat pulldown'],
  'pulldown': ['jalon'],
  'lat pulldown': ['jalon', 'jalon al pecho'],

  // Peso muerto / Deadlift
  'peso muerto': ['deadlift', 'dl'],
  'deadlift': ['peso muerto', 'dl'],
  'dl': ['deadlift', 'peso muerto'],

  // Peso muerto rumano / RDL
  'peso muerto rumano': ['romanian deadlift', 'rdl'],
  'romanian deadlift': ['peso muerto rumano', 'rdl'],
  'rdl': ['romanian deadlift', 'peso muerto rumano'],

  // Press militar / OHP
  'press militar': ['overhead press', 'ohp'],
  'overhead press': ['press militar', 'ohp'],
  'ohp': ['overhead press', 'press militar'],

  // Remo
  'remo con barra': ['barbell row', 'bent over row'],
  'barbell row': ['remo con barra', 'bent over row'],
  'bent over row': ['remo con barra', 'barbell row'],
};
