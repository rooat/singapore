
import 'package:protolith/blockchain/block/standard_block.dart';
import 'package:protolith/blockchain/chain/block_chain.dart';
import 'package:protolith/blockchain/chain/standard_block_chain.dart';
import 'package:protolith/blockchain/db/meta_data/memory_db.dart';
import 'package:protolith/blockchain/db/meta_data/meta_data_db.dart';
import 'package:protolith/blockchain/exceptions/unknown_block.dart';
import 'package:protolith/blockchain/hash.dart';
import 'package:singapore/beacon/beacon_block.dart';
import 'package:singapore/beacon/beacon_block_meta.dart';
import 'package:singapore/beacon/beacon_constants.dart';
import 'package:singapore/beacon/unfinalized/beacon_dag.dart';
import 'package:singapore/beacon/unfinalized/beacon_entry.dart';

class BeaconBlockChain<M extends BeaconBlockMeta, B extends BeaconBlock<M>> extends BlockChain<M, B> {

  /// the Unix time of the genesis beacon chain block at slot 0
  int genesisTime;


  /// The standard chain is synced as well, to use for POW.
  /// (Note; this is just the interface, data may come from elsewhere)
  StandardBlockChain eth1Chain;

  /// The unfinalized beacon blocks are stored in a leveled DAG.
  /// A path may be derived starting from the last finalized beacon state,
  ///  and derive a head.
  BeaconDag _beaconDag;
  BeaconDag get beaconBlocks => _beaconDag;

  /// Create a chain. This handles incoming blocks and updates the state.
  /// After creating the chain, the [metaDB] and [blockDB] should be
  ///  changed to the storage solution of choice.
  /// And a ETH 1.0 chain needs to be attached, by changing [eth1Chain].
  /// Once hooked up to storage and a ETH 1.0 chain,
  ///  one could create a beacon genesis block by calling the [genesis] function
  ///  and/or start syncing blocks (on top of existing storage data or not)
  ///  by calling [addBlock(block)] repeatedly.
  BeaconBlockChain(this.genesisTime) {
    // Create the DAG that will be used for tracking unfinalized blocks.
    _beaconDag = new BeaconDag();
  }

  Future genesis() async {
    BeaconBlock<M> genesisBlock = new BeaconBlock<M>();
    genesisBlock
      ..slot = 0
      ..parentHash = ZERO_HASH
      // TODO state root needs to be computed?
      ..stateRoot = null
      ..randaoReveal = EMPTY_SIGNATURE
      ..proposerSlashings = []
      ..casperSlashings = []
      ..attestations = []
      ..custodyReseeds = []
      ..custodyResponses = []
      ..deposits = []
      ..exits = [];

    // instead of processing, we just add the block, we change the state ourselves.
    await addValidBlock(genesisBlock);

    MetaDataDB tempDB = InMemoryMetaDataDB();
    M meta = await getBlockMeta(null, );
    // Initialize genesis state.
    await meta.genesis();
    // Apply all changes together
    // (prevent individual updates to every single latest-whatever data)
    metaDB.putDataset(tempDB);

    // Add the genesis block to the empty DAG
    _beaconDag.addNode(BeaconEntry(genesisBlock.hash, genesisBlock.slot));

    headBlockHash = genesisBlock.hash;
  }

  /// Returns the post-state for the block [blockHash].
  Future<M> getBlockMeta(Hash256 hash, {MetaDataDB db}) async {
    // Check if the block is known. If not, we cannot construct a post-state for the block.
    B b = await this.getBlock(hash);
    if (b == null) throw UnknownBlockException(hash, "Block hash is unknown. Cannot build state for it.");

    // Create the view for the block.
    BeaconBlockMeta meta = new BeaconBlockMeta(b.hash, b.slot, db ?? metaDB);

    return meta;
  }

  /// Prepare the [meta] to validate and process the [block]
  Future preProcessBlock(B block, M meta) async {
    // update the meta to the slot just before the block will be processed.
    while (meta.slot < block.slot - 1) {
      meta.nextSlot();
    }
  }

  /// Update the [meta] to handle the effect of processing [block]
  Future postProcessBlock(B block, M meta) async {
    // Add the block to the DAG of blocks
    //  (how we keep track of the unfinalized blocks)
    _beaconDag.addNode(new BeaconEntry(block.hash, block.slot));

    // Determine the head of the chain with this new information,
    //  and the updated state.
    // Find a path using the DAG (uses LMD GHOST),
    //  and pick the last block in it.
    BeaconEntry dagEntry = _beaconDag.findPath(headBlockHash).last;

    // Update the head of the chain.
    headBlockHash = dagEntry.blockHash;

    // TODO: if new blocks are finalized,
    //  then call _beaconDag.cleanup(() => ...)
    //  to remove finalized blocks from the DAG.
  }


  @override
  Future validateBlock(B block, M meta) async {
    // From spec:
    // For a beacon chain block, block, to be processed by a node, the following conditions must be met:

    // 1. The parent block with hash block.ancestor_hashes[0] has been processed and accepted.
    if (block.parentHash != meta.blockHash) throw Exception("Blockchain not synced, unknown parent hash reference.");
    // 2. The node has processed its state up to slot, block.slot - 1. [in a situation the slot is not active yet]
    if (block.slot == meta.slot + 1) throw Exception("Blockchain not synced, cannot add block #${block.slot} to beacon chain at slot #${meta.slot}.");
    // 3. The Ethereum 1.0 block pointed to by the state.processed_pow_receipt_root has been processed and accepted.
    StandardBlock currentEth1Ref = await eth1Chain.getBlock((await meta.getEth1Data()).blockHash);
    if (currentEth1Ref == null) throw Exception("Node is not synced with eth1.0 chain up to last block refered to by beacon state.");
    // 4. The node's local clock time is greater than or equal to state.genesis_time + block.slot * SLOT_DURATION.
    if ((new DateTime.now().millisecondsSinceEpoch ~/ 1000) >= (genesisTime + (block.slot * SLOT_DURATION))) throw Exception("Node time is not as far as block. Cannot accept block.");

    // validate the block like normal, using the rules as specified in the block class.
    super.validateBlock(block, meta);
  }

}
