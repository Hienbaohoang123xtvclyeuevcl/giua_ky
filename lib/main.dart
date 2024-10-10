import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ProductManager(),
    );
  }
}

class ProductManager extends StatefulWidget {
  @override
  _ProductManagerState createState() => _ProductManagerState();
}

class _ProductManagerState extends State<ProductManager> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  List<Product> _products = [];
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  void fetchProducts() async {
    final databaseReference = FirebaseDatabase.instance.ref();
    final snapshot = await databaseReference.child('products').once();

    if (snapshot.snapshot.value != null) {
      setState(() {
        _products = (snapshot.snapshot.value as Map).entries.map((entry) {
          final data = entry.value;
          return Product(
            id: entry.key,
            name: data['name'],
            type: data['type'],
            price: data['price'],
            imageUrl: data['imageUrl'],
          );
        }).toList();
      });
    }
  }

  Future<void> addProduct() async {
    if (_nameController.text.isNotEmpty &&
        _typeController.text.isNotEmpty &&
        _priceController.text.isNotEmpty &&
        _imageUrl != null) {
      final productId = Uuid().v4();

      try {
        final ref = FirebaseStorage.instance.ref().child('product_images').child('$productId.jpg');
        await ref.putFile(File(_imageUrl!));
        final imageUrl = await ref.getDownloadURL();

        final product = Product(
          id: productId,
          name: _nameController.text,
          type: _typeController.text,
          price: double.tryParse(_priceController.text) ?? 0,
          imageUrl: imageUrl,
        );

        final databaseReference = FirebaseDatabase.instance.ref();
        await databaseReference.child('products').child(productId).set({
          'name': product.name,
          'type': product.type,
          'price': product.price,
          'imageUrl': product.imageUrl,
        });

        _nameController.clear();
        _typeController.clear();
        _priceController.clear();
        setState(() {
          _products.add(product);
          _imageUrl = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sản phẩm đã được thêm thành công!')),
        );
      } catch (e) {
        print('Lỗi khi thêm sản phẩm: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi thêm sản phẩm: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng điền đầy đủ thông tin!')),
      );
    }
  }

  Future<void> editProduct(String id) async {
    final databaseReference = FirebaseDatabase.instance.ref();
    final snapshot = await databaseReference.child('products').child(id).once();

    if (snapshot.snapshot.value != null) {
      final data = snapshot.snapshot.value as Map;

      _nameController.text = data['name'];
      _typeController.text = data['type'];
      _priceController.text = data['price'].toString();
      _imageUrl = data['imageUrl'];

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Chỉnh sửa sản phẩm'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _nameController, decoration: InputDecoration(labelText: 'Tên sản phẩm')),
                TextField(controller: _typeController, decoration: InputDecoration(labelText: 'Loại sản phẩm')),
                TextField(controller: _priceController, decoration: InputDecoration(labelText: 'Giá')),
                ElevatedButton(
                  onPressed: _pickImage,
                  child: Text('Chọn hình ảnh'),
                ),
                if (_imageUrl != null) Image.network(_imageUrl!, width: 100, height: 100),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _updateProduct(id);
                  Navigator.of(context).pop();
                },
                child: Text('Lưu'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Hủy'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _updateProduct(String id) async {
    if (_nameController.text.isNotEmpty &&
        _typeController.text.isNotEmpty &&
        _priceController.text.isNotEmpty) {

      try {
        final databaseReference = FirebaseDatabase.instance.ref();
        await databaseReference.child('products').child(id).update({
          'name': _nameController.text,
          'type': _typeController.text,
          'price': double.tryParse(_priceController.text) ?? 0,
          'imageUrl': _imageUrl,
        });

        setState(() {
          final productIndex = _products.indexWhere((product) => product.id == id);
          if (productIndex != -1) {
            _products[productIndex] = Product(
              id: id,
              name: _nameController.text,
              type: _typeController.text,
              price: double.tryParse(_priceController.text) ?? 0,
              imageUrl: _imageUrl ?? '',
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sản phẩm đã được cập nhật thành công!')),
        );

        _nameController.clear();
        _typeController.clear();
        _priceController.clear();
        setState(() {
          _imageUrl = null;
        });
      } catch (e) {
        print('Lỗi khi cập nhật sản phẩm: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi cập nhật sản phẩm: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng điền đầy đủ thông tin!')),
      );
    }
  }

  Future<void> deleteProduct(String id) async {
    final databaseReference = FirebaseDatabase.instance.ref();
    final snapshot = await databaseReference.child('products').child(id).once();

    if (snapshot.snapshot.value != null) {
      final productData = snapshot.snapshot.value as Map;
      final imageUrl = productData['imageUrl'] as String;

      // Xóa hình ảnh trong Firebase Storage
      try {
        final ref = FirebaseStorage.instance.refFromURL(imageUrl);
        await ref.delete();
      } catch (e) {
        print('Lỗi khi xóa hình ảnh: $e');
      }

      // Xóa sản phẩm từ Realtime Database
      await databaseReference.child('products').child(id).remove();
      setState(() {
        _products.removeWhere((product) => product.id == id);
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageUrl = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Product Manager'),
      ),
      body: Column(
        children: [
          TextField(controller: _nameController, decoration: InputDecoration(labelText: 'Tên sản phẩm')),
          TextField(controller: _typeController, decoration: InputDecoration(labelText: 'Loại sản phẩm')),
          TextField(controller: _priceController, decoration: InputDecoration(labelText: 'Giá')),
          ElevatedButton(
            onPressed: _pickImage,
            child: Text('Chọn hình ảnh'),
          ),
          if (_imageUrl != null) Image.file(File(_imageUrl!), width: 100, height: 100),
          ElevatedButton(
            onPressed: addProduct,
            child: Text('Thêm sản phẩm'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text('${product.type} - \$${product.price}'),
                  leading: product.imageUrl != null ? Image.network(product.imageUrl!, width: 50) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => editProduct(product.id),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => deleteProduct(product.id),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class Product {
  final String id;
  final String name;
  final String type;
  final double price;
  final String imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    required this.imageUrl,
  });
}
