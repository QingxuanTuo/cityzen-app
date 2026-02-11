class CityOption {
  final String key; // 用于保存
  final String name; // 展示名
  final double lat;
  final double lon;

  const CityOption(this.key, this.name, this.lat, this.lon);
}

const supportedCities = <CityOption>[
  CityOption('rome', 'Rome, Italy', 41.902782, 12.496366),
  CityOption('milan', 'Milan, Italy', 45.464211, 9.190347),
  CityOption('naples', 'Naples, Italy', 40.851775, 14.268124),
  CityOption('turin', 'Turin, Italy', 45.070312, 7.686856),
  CityOption('palermo', 'Palermo, Italy', 38.115697, 13.361268),
  CityOption('genoa', 'Genoa, Italy', 44.405650, 8.946256),
  CityOption('bologna', 'Bologna, Italy', 44.494887, 11.342616),
  CityOption('florence', 'Florence, Italy', 43.769562, 11.255814),
  CityOption('venice', 'Venice, Italy', 45.440847, 12.315515),
  CityOption('bari', 'Bari, Italy', 41.117143, 16.871871),
  CityOption('messina', 'Messina, Italy', 38.193814, 15.554015),
  CityOption('reggio_calabria', 'Reggio Calabria, Italy', 38.111227, 15.647594),
  CityOption('catania', 'Catania, Italy', 37.507877, 15.083030),
  CityOption('verona', 'Verona, Italy', 45.438384, 10.991622),
  CityOption('padua', 'Padua, Italy', 45.406435, 11.876761),
  CityOption('trieste', 'Trieste, Italy', 45.649526, 13.776818),
  CityOption('cagliari', 'Cagliari, Italy', 39.223841, 9.121661),
];
