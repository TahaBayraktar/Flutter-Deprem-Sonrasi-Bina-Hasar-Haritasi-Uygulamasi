import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'firebase_options.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(HaritaUygulamasi());
}
class HaritaUygulamasi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HaritaSayfasi(),
    );
  }
}
class HaritaSayfasi extends StatefulWidget {
  @override
  _HaritaSayfasiState createState() => _HaritaSayfasiState();
}
class _HaritaSayfasiState extends State<HaritaSayfasi> {
  late GoogleMapController _haritaController;
  Set<Marker> _isaretler = {};
  late String _seciliHasarDurumu;
  String duzenlenmisHasarDurumu = 'Hafif';
  Set<Polygon> _cokgenler = {};
  @override
  void initState() {
    super.initState();
    _seciliHasarDurumu = 'Hafif';
    _firestoreDanIsaretleriGetir();
  }
  String _belgeIdUret() {
    DateTime suan = DateTime.now();
    return '${suan.year}-${suan.month}-${suan.day} ${suan.hour}:${suan.minute}:${suan.second}';
  }
  void _isaretTiklandi(String? isaretId) {
    if (isaretId != null) {
      setState(() {
        _seciliIsaretId = isaretId;
      });
    } else {
      setState(() {
        _seciliIsaretId = '';
      });
    }
  }
  void _haritayaCokgenEkle(String kategori, List<LatLng> noktalar) {
    Color cokgenRengi = Colors.blue;
    switch (kategori) {
      case 'Hafif':
        cokgenRengi = Colors.green;
        break;
      case 'Orta':
        cokgenRengi = Colors.orange;
        break;
      case 'Ağır':
        cokgenRengi = Colors.red;
        break;
    }
    Polygon yeniCokgen = Polygon(
      polygonId: PolygonId(kategori),
      points: noktalar,
      strokeWidth: 2,
      strokeColor: cokgenRengi,
      fillColor: cokgenRengi.withOpacity(0.2),
    );
    setState(() {
      _cokgenler.add(yeniCokgen);
    });
  }
  DateTime suan = DateTime.now();
  void _isaretiDuzenle(String belgeId) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentSnapshot belge = await firestore.collection('Harita').doc(belgeId).get();
      if (belge.exists) {
        GeoPoint konum = belge['position'];
        String binaAdi = belge['buildingName'];
        String hasarDurumu = belge['damageStatus'];
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            String duzenlenmisBinaAdi = binaAdi;
            String duzenlenmisHasarDurumu = hasarDurumu;
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: Text('Bina Bilgilerini Düzenle'),
                  content: Column(
                    children: [
                      TextField(
                        onChanged: (deger) {
                          setState(() {
                            duzenlenmisBinaAdi = deger;
                          });
                        },
                        decoration: InputDecoration(labelText: 'Yeni Bina Adı'),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Text('Yeni Hasar Durumu: '),
                          SizedBox(width: 10),
                          Expanded(
                            child: DropdownButton<String>(
                              value: duzenlenmisHasarDurumu,
                              onChanged: (String? yeniDeger) {
                                if (yeniDeger != null) {
                                  setState(() {
                                    duzenlenmisHasarDurumu = yeniDeger;
                                  });
                                }
                              },
                              items: <String>['Hafif', 'Orta', 'Ağır']
                                  .map<DropdownMenuItem<String>>(
                                    (String deger) {
                                  return DropdownMenuItem<String>(
                                    value: deger,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(deger),
                                    ),
                                  );
                                },
                              ).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Marker guncellenmisIsaret = Marker(
                          markerId: MarkerId(belgeId),
                          position: LatLng(konum.latitude, konum.longitude),
                          infoWindow: InfoWindow(
                            title: duzenlenmisBinaAdi,
                            snippet: 'Hasar Durumu: ',
                          ),
                          icon: _isaretIkonunuGetir(duzenlenmisHasarDurumu),
                          onTap: () => _isaretTiklandi(belgeId),
                        );
                        setState(() {
                          _isaretler.removeWhere((isaret) => isaret.markerId.value == belgeId);
                          _isaretler.add(guncellenmisIsaret);
                        });
                        await _firestoreGuncelle(belgeId, duzenlenmisBinaAdi, duzenlenmisHasarDurumu);
                        Navigator.pop(context);
                        await _firestoreDanIsaretleriGetir();
                      },
                      child: Text('Kaydet'),
                    ),
                  ],
                );
              },
            );
          },
        );
      } else {
        print('Düzenlenecek bir işaretçi bulunamadı. Belge ID: $belgeId');
      }
    } catch (hata) {
      print('İşaretçi düzenlenirken bir hata oluştu: $hata');
    }
  }
  Future<void> _firestoreGuncelle(String belgeId, String duzenlenmisBinaAdi, String duzenlenmisHasarDurumu) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      await firestore.collection('Harita').doc(belgeId).update({
        'buildingName': duzenlenmisBinaAdi,
        'damageStatus': duzenlenmisHasarDurumu,
      });
      print('İşaretçi Firestore\'da başarıyla güncellendi. Belge ID: $belgeId');
    } catch (hata) {
      print('İşaretçi Firestore\'da güncellenirken bir hata oluştu: $hata');
    }
  }
  void _cokgenleriGuncelle(Set<Marker> isaretler) {
    Map<String, Set<Marker>> kategorilendirilmisIsaretler = {};
    isaretler.forEach((isaret) {
      String kategori = isaret.infoWindow!.snippet!.split(":")[1].trim();
      if (!kategorilendirilmisIsaretler.containsKey(kategori)) {
        kategorilendirilmisIsaretler[kategori] = {};
      }

      kategorilendirilmisIsaretler[kategori]!.add(isaret);
    });

    setState(() {
      _cokgenler.clear();
    });
    kategorilendirilmisIsaretler.forEach((kategori, isaretler) {
      if (isaretler.length > 1) {
        List<LatLng> cokgenNoktalari = isaretler.map((isaret) => isaret.position).toList();
        _haritayaCokgenEkle(kategori, cokgenNoktalari);
      }
    });
  }
  Future<void> _firestoreDanIsaretleriGetir() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    QuerySnapshot sorguSonucu = await firestore.collection('Harita').get();

    Set<Marker> yeniIsaretler = sorguSonucu.docs.map((DocumentSnapshot belge) {
      GeoPoint konum = belge['position'];
      String binaAdi = belge['buildingName'];
      String hasarDurumu = belge['damageStatus'];
      return Marker(
        markerId: MarkerId(belge.id),
        position: LatLng(konum.latitude, konum.longitude),
        infoWindow: InfoWindow(
          title: binaAdi,
          snippet: 'Hasar Durumu: $hasarDurumu',
        ),
        icon: _isaretIkonunuGetir(hasarDurumu),
        onTap: () => _isaretTiklandi(belge.id),
      );
    }).toSet();

    setState(() {
      _isaretler = yeniIsaretler;
    });
    _cokgenleriGuncelle(yeniIsaretler);
  }
  BitmapDescriptor _isaretIkonunuGetir(String hasarDurumu) {
    switch (hasarDurumu) {
      case 'Hafif':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 'Orta':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case 'Ağır':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }
  String _seciliIsaretId = '';
  void _haritaUzerindeTiklandi(LatLng konum) async {
    setState(() {
      _seciliIsaretId = '';
    });
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        String binaAdi = '';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Bina Bilgileri'),
              content: Column(
                children: [
                  TextField(
                    onChanged: (deger) {
                      binaAdi = deger;
                    },
                    decoration: InputDecoration(labelText: 'Bina Adı'),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Hasar Durumu:'),
                      SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<String>(
                          value: duzenlenmisHasarDurumu,
                          onChanged: (String? yeniDeger) {
                            if (yeniDeger != null) {
                              setState(() {
                                duzenlenmisHasarDurumu = yeniDeger;
                              });
                            }
                          },
                          items: <String>['Hafif', 'Orta', 'Ağır']
                              .map<DropdownMenuItem<String>>(
                                (String deger) {
                              return DropdownMenuItem<String>(
                                value: deger,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Text(deger),
                                ),
                              );
                            },
                          ).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('İptal'),
                ),
                TextButton(
                  onPressed: () async {
                    Marker yeniIsaret = Marker(
                      markerId: MarkerId(konum.toString()),
                      position: konum,
                      infoWindow: InfoWindow(
                        title: binaAdi,
                        snippet: 'Hasar Durumu: $duzenlenmisHasarDurumu',
                      ),
                      icon: _isaretIkonunuGetir(duzenlenmisHasarDurumu),
                      onTap: () => _isaretTiklandi(null),
                    );

                    setState(() {
                      _isaretler.add(yeniIsaret);
                    });

                    await _firestoreKaydet(yeniIsaret, binaAdi, duzenlenmisHasarDurumu);

                    Navigator.pop(context);

                    await _firestoreDanIsaretleriGetir();
                  },
                  child: Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Future<void> _firestoreKaydet(Marker isaret, String binaAdi, String hasarDurumu) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // _belgeIdUret fonksiyonu ile yeni bir ID oluştur
      String yeniBelgeId = _belgeIdUret();

      // set metodunu bekleyerek Firestore'a ekle
      await firestore.collection('Harita').doc(yeniBelgeId).set({
        'position': GeoPoint(isaret.position.latitude, isaret.position.longitude),
        'buildingName': binaAdi,
        'damageStatus': hasarDurumu,
      });
      print('İşaretçi Firestore\'a başarıyla kaydedildi. Belge ID: $yeniBelgeId');
    } catch (hata) {
      print('İşaretçi Firestore\'a kaydedilirken bir hata oluştu: $hata');
    }
  }
  void _isaretiSil(String belgeId) async {
    try {
      bool silmeOnayi = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('İşareti Sil'),
            content: Text('Seçili işareti silmek istediğinizden emin misiniz?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text('Hayır'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(true);
                },
                child: Text('Evet'),
              ),
            ],
          );
        },
      );
      if (silmeOnayi == true) {
        print('Silme işlemine başlanıyor. Silinecek Belge ID: $belgeId');

        if (_seciliIsaretId.isNotEmpty && _seciliIsaretId == belgeId) {
          FirebaseFirestore firestore = FirebaseFirestore.instance;
          await firestore.collection('Harita').doc(belgeId).delete();
          print('İşaretçi Firestore\'dan başarıyla silindi. Belge ID: $belgeId');

          setState(() {
            _isaretler.removeWhere((isaret) => isaret.markerId.value == belgeId);
          });
          setState(() {
            _seciliIsaretId = '';
          });
        } else {
          print('Silinecek bir işaretçi seçilmedi. _seciliIsaretId: $_seciliIsaretId, Belge ID: $belgeId');
        }

        await _firestoreDanIsaretleriGetir();
        _cokgenleriGuncelle(_isaretler);
      }
    } catch (hata) {
      print('İşaretçi Firestore\'dan silinirken bir hata oluştu: $hata');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bina Hasar Haritası'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) {
                _haritaController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: LatLng(38.3556, 38.3095),
                zoom: 12.0,
              ),
              markers: _isaretler,
              polygons: _cokgenler,
              onTap: _haritaUzerindeTiklandi,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  if (_seciliIsaretId.isNotEmpty) {
                    _isaretiSil(_seciliIsaretId);
                  } else {
                    print('Silinecek bir işaretçi seçilmedi.');
                  }
                },
                child: Text('Sil'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_seciliIsaretId.isNotEmpty) {
                    _isaretiDuzenle(_seciliIsaretId);
                  } else {
                    print('Düzenlenecek bir işaretçi seçilmedi.');
                  }
                },
                child: Text('Düzenle'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


