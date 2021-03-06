import 'package:protolith/blockchain/hash.dart';
import 'package:protolith/blockchain/meta/blocks/meta.dart';
import 'package:protolith/blockchain/db/meta_data/meta_data_db.dart';
import 'package:protolith/crypto/data_util.dart';
import 'package:singapore/beacon/beacon_block_meta.dart';
import 'package:singapore/beacon/beacon_constants.dart';
import 'package:singapore/beacon/randao/randao_data.dart';

mixin RandaoMeta on BlockMeta implements SlotMeta {

  Future<RandaoData> getRandaoData() =>
      db.getData(MetaDataKey("randao", blockHash)).then(decodeRandaoData);

  Future setRandaoData(RandaoData value) =>
      db.putData(MetaDataKey("randao", blockHash), encodeRandaoData(value));


  Future<Hash256> getLatestRandaoMix(int slot) =>
      db.getData(MetaDataKey("latest_randao_mix", blockHash, [slot % LATEST_RANDAO_MIXES_LENGTH])).then(decHash256);

  Future setLatestRandaoMix(int slot, Hash256 value) =>
      db.putData(MetaDataKey("latest_randao_mix", blockHash, [slot % LATEST_RANDAO_MIXES_LENGTH]), value.uint8list);

  Future<Hash256> getLatestVdfOutput(int nr) =>
      db.getData(MetaDataKey("vdf_output", blockHash, [nr % LATEST_VDF_OUTPUTS_LENGTH])).then(decHash256);

  Future setLatestVdfOutput(int nr, Hash256 value) =>
      db.putData(MetaDataKey("vdf_output", blockHash, [nr % LATEST_VDF_OUTPUTS_LENGTH]), value.uint8list);

  Future genesis() async {
    await super.genesis();
    await setRandaoData(
        RandaoData(
            GENESIS_START_SHARD, GENESIS_START_SHARD,
            GENESIS_SLOT, GENESIS_SLOT,
            ZERO_HASH, ZERO_HASH)
        );

    // initialize randao mixes
    await Future.wait(new List.generate(LATEST_RANDAO_MIXES_LENGTH,
            (i) => setLatestRandaoMix(i, ZERO_HASH)));
    // initialize vdf outputs
    await Future.wait(new List.generate(LATEST_VDF_OUTPUTS_LENGTH,
            (i) => setLatestVdfOutput(i, ZERO_HASH)));
  }

  /// Returns the randao mix at a recent [slot].
  Future<Hash256> getRandaoMix(int slot) {
    assert(this.slot < slot + LATEST_RANDAO_MIXES_LENGTH);
    assert(slot <= this.slot);
    return getLatestRandaoMix(slot);
  }

}