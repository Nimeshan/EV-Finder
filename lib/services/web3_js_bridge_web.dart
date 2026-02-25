// Web implementation using dart:js for MetaMask interop.
import 'dart:async';
import 'dart:js' as js;

class Web3JsBridge {
  static const bool isAvailable = true;

  static Future<dynamic> promiseToFuture(dynamic promise) async {
    final completer = Completer<dynamic>();
    try {
      js.context.callMethod('eval', [
        '''
        (function() {
          var promise = arguments[0];
          var resolve = arguments[1];
          promise.then(function(value) { resolve(value); })
                .catch(function(error) { resolve({success: false, error: error.message || error.toString()}); });
        })
        '''
      ]).apply([
        promise,
        (value) {
          if (!completer.isCompleted) completer.complete(value);
        }
      ]);
      return completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('MetaMask connection timed out.'),
      );
    } catch (e) {
      return promise;
    }
  }

  static bool hasConnectMetaMask() =>
      js.context.hasProperty('connectMetaMask');
  static bool hasSwitchToSepolia() =>
      js.context.hasProperty('switchToSepolia');
  static Future<dynamic> switchToSepolia() async {
    final p = js.context.callMethod('switchToSepolia', []);
    return promiseToFuture(p);
  }

  static Future<dynamic> connectMetaMask() async {
    final p = js.context.callMethod('connectMetaMask', []);
    return promiseToFuture(p);
  }

  static bool hasGetMetaMaskAccount() =>
      js.context.hasProperty('getMetaMaskAccount');
  static Future<String?> getMetaMaskAccount() async {
    final p = js.context.callMethod('getMetaMaskAccount', []);
    final result = await promiseToFuture(p);
    if (result != null && result is String && result.isNotEmpty) {
      return result;
    }
    return null;
  }

  static bool hasSendTransaction() =>
      js.context.hasProperty('sendTransaction');
  static void defineSendTransaction() {
    js.context.callMethod('eval', [
      '''
      window.sendTransaction = async function(from, to, amount) {
        if (typeof window.ethereum === 'undefined') return {success: false, error: 'MetaMask not found'};
        try {
          const txHash = await window.ethereum.request({
            method: 'eth_sendTransaction',
            params: [{ from: from, to: to, value: amount, gas: '0x5208' }]
          });
          return {success: true, txHash: txHash};
        } catch (error) {
          return {success: false, error: error.message || error.toString()};
        }
      };
      '''
    ]);
  }

  static dynamic sendTransaction(
      String from, String to, String amountHex) {
    return js.context.callMethod('sendTransaction', [from, to, amountHex]);
  }

  static bool hasSendContractTransaction() =>
      js.context.hasProperty('sendContractTransaction');
  static void defineSendContractTransaction() {
    js.context.callMethod('eval', [
      '''
      window.sendContractTransaction = async function(contractAddress, encodedData, fromAddress) {
        if (typeof window.ethereum === 'undefined') return {success: false, error: 'MetaMask not found'};
        try {
          const gasEstimate = await window.ethereum.request({
            method: 'eth_estimateGas',
            params: [{ from: fromAddress, to: contractAddress, data: encodedData }]
          });
          const txHash = await window.ethereum.request({
            method: 'eth_sendTransaction',
            params: [{ from: fromAddress, to: contractAddress, data: encodedData, gas: gasEstimate }]
          });
          return {success: true, txHash: txHash};
        } catch (error) {
          return {success: false, error: error.message || error.toString()};
        }
      };
      '''
    ]);
  }

  static bool hasSendContractTransactionWithValue() =>
      js.context.hasProperty('sendContractTransactionWithValue');
  static void defineSendContractTransactionWithValue() {
    js.context.callMethod('eval', [
      '''
      window.sendContractTransactionWithValue = async function(contractAddress, encodedData, fromAddress, valueHex) {
        if (typeof window.ethereum === 'undefined') return {success: false, error: 'MetaMask not found'};
        try {
          const gasEstimate = await window.ethereum.request({
            method: 'eth_estimateGas',
            params: [{ from: fromAddress, to: contractAddress, data: encodedData, value: valueHex }]
          });
          const txHash = await window.ethereum.request({
            method: 'eth_sendTransaction',
            params: [{ from: fromAddress, to: contractAddress, data: encodedData, value: valueHex, gas: gasEstimate }]
          });
          return {success: true, txHash: txHash};
        } catch (error) {
          return {success: false, error: error.message || error.toString()};
        }
      };
      '''
    ]);
  }

  static Future<dynamic> sendContractTransaction(
      String contractAddr, String dataHex, String from) async {
    final promise = js.context.callMethod(
        'sendContractTransaction', [contractAddr, dataHex, from]);
    return promiseToFuture(promise);
  }

  static Future<dynamic> sendContractTransactionWithValue(
      String contractAddr, String dataHex, String from, String valueHex) async {
    final promise = js.context.callMethod('sendContractTransactionWithValue',
        [contractAddr, dataHex, from, valueHex]);
    return promiseToFuture(promise);
  }

  static bool getJsResultSuccess(dynamic result) {
    if (result == null) return false;
    try {
      return (result as js.JsObject)['success'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  static String? getJsResultTxHash(dynamic result) {
    if (result == null) return null;
    try {
      return (result as js.JsObject)['txHash'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String? getJsResultError(dynamic result) {
    if (result == null) return null;
    try {
      return (result as js.JsObject)['error'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String? getJsResultAddress(dynamic result) {
    if (result == null) return null;
    try {
      return (result as js.JsObject)['address'] as String?;
    } catch (_) {
      return null;
    }
  }
}
