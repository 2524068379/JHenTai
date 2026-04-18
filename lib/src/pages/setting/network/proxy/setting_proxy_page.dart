import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../../../../setting/network_setting.dart';

class SettingProxyPage extends StatefulWidget {
  const SettingProxyPage({super.key});

  @override
  State<SettingProxyPage> createState() => _SettingProxyPageState();
}

class _SettingProxyPageState extends State<SettingProxyPage> {
  JProxyType proxyType = networkSetting.proxyType.value;
  String proxyAddress = networkSetting.proxyAddress.value;
  String? proxyUsername = networkSetting.proxyUsername.value;
  String? proxyPassword = networkSetting.proxyPassword.value;
  late final TextEditingController proxyAddressController;
  late final TextEditingController proxyUsernameController;
  late final TextEditingController proxyPasswordController;

  @override
  void initState() {
    super.initState();
    proxyAddressController = TextEditingController(text: proxyAddress);
    proxyUsernameController = TextEditingController(text: proxyUsername);
    proxyPasswordController = TextEditingController(text: proxyPassword);
  }

  @override
  void dispose() {
    proxyAddressController.dispose();
    proxyUsernameController.dispose();
    proxyPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('proxySetting'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              networkSetting.saveProxy(proxyType, proxyAddress, proxyUsername, proxyPassword);
              toast('success'.tr);
            },
          ),
        ],
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            _buildProxyType(),
            _buildProxyAddress(),
            _buildProxyUsername(),
            _buildProxyPassword(),
          ],
        ),
      ).withListTileTheme(context),
    );
  }

  Widget _buildProxyType() {
    return ListTile(
      title: Text('proxyType'.tr),
      trailing: Obx(
        () => DropdownButton<JProxyType>(
          value: networkSetting.proxyType.value,
          alignment: Alignment.center,
          items: [
            DropdownMenuItem(value: JProxyType.system, child: Text('systemProxy'.tr)),
            DropdownMenuItem(value: JProxyType.http, child: Text('httpProxy'.tr)),
            DropdownMenuItem(value: JProxyType.socks5, child: Text('socks5Proxy'.tr)),
            DropdownMenuItem(value: JProxyType.socks4, child: Text('socks4Proxy'.tr)),
            DropdownMenuItem(value: JProxyType.direct, child: Text('directProxy'.tr)),
          ],
          onChanged: (JProxyType? value) {
            proxyType = value!;
            networkSetting.saveProxy(proxyType, proxyAddress, proxyUsername, proxyPassword);
          },
        ),
      ),
    );
  }

  Widget _buildProxyAddress() {
    return ListTile(
      title: Text('address'.tr),
      trailing: SizedBox(
        width: 150,
        child: TextField(
          controller: proxyAddressController,
          decoration: const InputDecoration(isDense: true, labelStyle: TextStyle(fontSize: 12)),
          textAlign: TextAlign.center,
          onChanged: (String value) => proxyAddress = value,
          enabled: networkSetting.proxyType.value != JProxyType.system && networkSetting.proxyType.value != JProxyType.direct,
        ),
      ),
      enabled: networkSetting.proxyType.value != JProxyType.system && networkSetting.proxyType.value != JProxyType.direct,
    );
  }

  Widget _buildProxyUsername() {
    return ListTile(
      title: Text('userName'.tr),
      trailing: SizedBox(
        width: 150,
        child: TextField(
          controller: proxyUsernameController,
          decoration: const InputDecoration(isDense: true, labelStyle: TextStyle(fontSize: 12)),
          textAlign: TextAlign.center,
          onChanged: (String value) => proxyUsername = value,
          enabled: networkSetting.proxyType.value != JProxyType.system && networkSetting.proxyType.value != JProxyType.direct,
        ),
      ),
      enabled: networkSetting.proxyType.value != JProxyType.system && networkSetting.proxyType.value != JProxyType.direct,
    );
  }

  Widget _buildProxyPassword() {
    return ListTile(
      title: Text('password'.tr),
      trailing: SizedBox(
        width: 150,
        child: TextField(
          controller: proxyPasswordController,
          decoration: const InputDecoration(isDense: true, labelStyle: TextStyle(fontSize: 12)),
          textAlign: TextAlign.center,
          onChanged: (String value) => proxyPassword = value,
          obscureText: true,
          enabled: networkSetting.proxyType.value != JProxyType.system && networkSetting.proxyType.value != JProxyType.direct,
        ),
      ),
      enabled: networkSetting.proxyType.value != JProxyType.system && networkSetting.proxyType.value != JProxyType.direct,
    );
  }
}
