import 'dart:typed_data';

import 'package:protolith/blockchain/hash.dart';
import 'package:protolith/blockchain/meta/blocks/meta.dart';
import 'package:protolith/blockchain/db/meta_data/meta_data_db.dart';
import 'package:singapore/beacon/validators/validator.dart';

class ValidatorsData {

  /// Validator registry
  List<Validator> validatorRegistry;
  List<int> validatorBalances;
  int validatorRegistryUpdateSlot;
  int validatorRegistryExitCount;

  /// For light clients to track deltas
  Hash256 validatorRegistryDeltaChainTip;

  Hash256 getLatestAttestationTarget(Validator v) {
    // TODO get target
    return null;
  }

}

ValidatorsData decodeValidatorsData(Uint8List data) => null;
Uint8List encodeValidatorsData(ValidatorsData data) => null;

mixin ValidatorRegistryMeta on BlockMeta {

  Future<ValidatorsData> getValidatorsData() =>
      db.getData(MetaDataKey("validators_data", blockHash)).then(decodeValidatorsData);

  Future setValidatorsData(ValidatorsData value) =>
      db.putData(MetaDataKey("validators_data", blockHash), encodeValidatorsData(value));

}
