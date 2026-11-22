import 'dart:convert';
import 'dart:typed_data';

/// A 120x160 receipt-like PNG for photo widget tests and goldens (generated, no real data).
final Uint8List samplePhotoPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAHgAAACgCAIAAABIaz/HAAABR0lEQVR42u3aqw2AMBRA0Y5TyQDVTEjQTMIISObAkaDwxTQp'
  'JAVOcic4or/XsC5z1rFvquyqGkCDBi3QoEGDBg1aoEGDBg0atBqCTql/XaBBgwYNGjRo0KBBgwYNGjRo0AINGjRo0KAFGjRo'
  '0KBB61bocZh+GOjvQgs0aNCgQYMWaNCgQbuCN3jTAw0atDUaNGiBBg0aNGjQAu2twxQcNGjQAg0aNGjQoAUaNGjQ3jpMwUGD'
  '9q/DGg0aNGiBBg0aNGjQcjP03QA0aP86bIYCDRo0aNCgBRo0aFNw0KBBW6NthqBBgwYt0KBBgwbtrcMUHDRo0NZomyFogQYN'
  'GjRo0ALtrcMUHDRo/zoEGjRo0KBBCzRo0KBBgxZo0KBLoWPslAUaNGjQoEGDdrxzjgYNGjRogQYNGjRo0AINGjRo0KAFGjRo'
  '0I9Bn2T+5AYfdy52AAAAAElFTkSuQmCC',
);
