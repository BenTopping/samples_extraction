require 'rails_helper'
require 'remote_assets_helper'

RSpec.describe 'Assets::Export' do
  include RemoteAssetsHelper

  describe 'Export' do
    context '#racking_info' do
      it 'unquotes sample uuid and sample_tube, ignoring unrelated attributes' do
        uuid = uuid
        asset = create(:asset)
        well1 = create(:asset)
        well2 = create(:asset)

        sample_tube = create(:asset)
        well1.facts << [
          create(:fact, predicate: 'sample_uuid', object: TokenUtil.quote(uuid)),
          create(:fact, predicate: 'this will be ignored', object: 'for sure')
        ]
        well2.facts << [
          create(:fact, predicate: 'sample_tube', object_asset: sample_tube),
          create(:fact, predicate: 'study_uuid', object: TokenUtil.quote(uuid)),
          create(:fact, predicate: 'sanger_sample_name', object: "name1")
        ]

        asset.facts << [
          create(:fact, predicate: 'contains', object_asset: well1),
          create(:fact, predicate: 'contains', object_asset: well2)
        ]

        expect(asset.racking_info(well1)).to eq({sample_uuid: TokenUtil.unquote(uuid)})
        expect(asset.racking_info(well2)).to eq({
          sample_tube_uuid: sample_tube.uuid,
          sanger_sample_name: 'name1'
        })
      end

      it 'generates an attribute object for a well' do
        facts = %Q{
          :s1 :a :SampleTube .
          :s2 :a :SampleTube .
          :s3 :a :SampleTube .
          :s4 :a :SampleTube .
          :tube1   :a                 :Tube ;
                   :location          "A1" ;
                   :sample_tube       :s1 .
          :tube2   :a                 :Tube ;
                   :location          "B1" ;
                   :sample_tube       :s2 .
          :tube3   :a                 :Tube ;
                   :location          "C1" ;
                   :sample_tube       :s3 .
          :tube4   :a                 :Tube ;
                   :location          "D1" ;
                   :sample_tube       :s4 .

          :rack1   :a                 :TubeRack ;
                   :contains          :tube1, :tube2, :tube3, :tube4 .
        }
        @assets = SupportN3::parse_facts(facts)

        @rack1 = Asset.find_by(uuid: 'rack1')
        expect(@rack1.attributes_to_update).to eq([
          {sample_tube_uuid: "s1", location: "A1"},
          {sample_tube_uuid: "s2", location: "B1"},
          {sample_tube_uuid: "s3", location: "C1"},
          {sample_tube_uuid: "s4", location: "D1"}])
      end

    end
    context '#update_plate' do
      let(:step_type) { create :step_type }
      let(:step) { create :step, step_type: step_type, state: Step::STATE_RUNNING }
      let(:updates) { FactChanges.new }
      let(:plate) { build_remote_plate }
      let(:asset) { create :asset }
      before do

      end
      it 'updates all wells uuids at same location' do
        well = create :asset
        well.facts << Fact.create(predicate: 'location', object: 'A1')
        well2 = create :asset
        well2.facts << Fact.create(predicate: 'location', object: 'A4')
        asset.facts << Fact.create(predicate: 'contains', object_asset_id: well.id)
        asset.facts << Fact.create(predicate: 'contains', object_asset_id: well2.id)

        expect(well.uuid).not_to eq(plate.wells.first.uuid)
        expect(well2.uuid).not_to eq(plate.wells.last.uuid)

        asset.update_plate(plate, updates)
        updates.apply(step)
        expect(asset.facts.with_predicate('contains').count).to eq(plate.wells.count)
        well.reload
        well2.reload
        expect(well.uuid).to eq(plate.wells.first.uuid)
        expect(well2.uuid).to eq(plate.wells.last.uuid)
      end
    end

    context '#update_sequencescape' do
      let(:step_type) { create :step_type }
      let(:step) { create :step, step_type: step_type, state: Step::STATE_RUNNING }
      let(:user) { create :user, username: 'test' }
      let(:print_config) { {"Plate"=>'Pum', "Tube"=>'Pim'} }
      let(:plate) { build_remote_plate }
      let(:asset) { create :asset }

      it 'updates a plate in sequencescape' do
        allow(SequencescapeClient).to receive(:version_1_find_by_uuid).with(asset.uuid).and_return(nil)
        allow(SequencescapeClient).to receive(:version_1_find_by_uuid).with(plate.uuid).and_return(plate)
        allow(SequencescapeClient).to receive(:find_by_uuid).with(asset.uuid).and_return(nil)
        allow(SequencescapeClient).to receive(:find_by_uuid).with(plate.uuid).and_return(plate)
        allow(SequencescapeClient).to receive(:create_plate).and_return(plate)
        barcode = double('barcode')
        allow(barcode).to receive(:prefix).and_return('DN')
        allow(barcode).to receive(:number).and_return('123')
        allow(plate).to receive(:barcode).and_return(barcode)

        expect(asset.facts.where(predicate: 'contains').count).to eq(0)
        asset.update_sequencescape(print_config, user, step).apply(step)
        asset.refresh
        expect(asset.facts.where(predicate: 'contains').count).to eq(plate.wells.count)
      end

    end

    context '#attributes_to_update' do
      it 'can convert location to Sequencescape location format' do
        %Q{
          I have a tube rack that contains 4 tubes with names tube1, tube2,
          tube3 and tube4.
          tube1 is in location A01, tube2 in B01, tube3 in C01 and tube4 in D1.
          Each tube has a sample tube inside, with names s1, s2, s3 and s4.
        }
        facts = %Q{
          :s1 :a :SampleTube .
          :s2 :a :SampleTube .
          :s3 :a :SampleTube .
          :s4 :a :SampleTube .
          :rack2   :a                 :TubeRack ;
                   :contains          :tube1, :tube2, :tube3, :tube4 .

          :tube1   :a                 :Tube ;
                   :location          "A01" ;
                   :sample_tube       :s1 .
          :tube2   :a                 :Tube ;
                   :location          "B01" ;
                   :sample_tube       :s2 .
          :tube3   :a                 :Tube ;
                   :location          "C01" ;
                   :sample_tube       :s3 .
          :tube4   :a                 :Tube ;
                   :location          "D1" ;
                   :sample_tube       :s4 .
        }
        @assets = SupportN3::parse_facts(facts)
        @rack2 = Asset.find_by(uuid: 'rack2')
        expect(@rack2.attributes_to_update).to eq([
          {sample_tube_uuid: "s1", location: "A1"},
          {sample_tube_uuid: "s2", location: "B1"},
          {sample_tube_uuid: "s3", location: "C1"},
          {sample_tube_uuid: "s4", location: "D1"}])
      end
      it 'generates the attributes when the locations are not duplicated' do
        facts = %Q{
          :s1 :a :SampleTube .
          :s2 :a :SampleTube .
          :s3 :a :SampleTube .
          :s4 :a :SampleTube .
          :rack2   :a                 :TubeRack ;
                   :contains          :tube1, :tube2, :tube3, :tube4 .

          :tube1   :a                 :Tube ;
                   :location          "A1" ;
                   :sample_tube       :s1 .
          :tube2   :a                 :Tube ;
                   :location          "B1" ;
                   :sample_tube       :s2 .
          :tube3   :a                 :Tube ;
                   :location          "C1" ;
                   :sample_tube       :s3 .
          :tube4   :a                 :Tube ;
                   :location          "D1" ;
                   :sample_tube       :s4 .
        }
        @assets = SupportN3::parse_facts(facts)
        @rack2 = Asset.find_by(uuid: 'rack2')
        expect(@rack2.attributes_to_update).to eq([
          {sample_tube_uuid: "s1", location: "A1"},
          {sample_tube_uuid: "s2", location: "B1"},
          {sample_tube_uuid: "s3", location: "C1"},
          {sample_tube_uuid: "s4", location: "D1"}])
      end

      it 'fails when trying to generate attributes when the locations are duplicated' do
        facts = %Q{
          :s1 :a :SampleTube .
          :s2 :a :SampleTube .
          :s3 :a :SampleTube .
          :s4 :a :SampleTube .
          :rack2   :a                 :TubeRack ;
                   :contains          :tube1, :tube2, :tube3, :tube4 .
          :tube1   :a                 :Tube ;
                   :location          "A1" ;
                   :sample_tube       :s1 .
          :tube2   :a                 :Tube ;
                   :location          "B1" ;
                   :sample_tube       :s2 .
          :tube3   :a                 :Tube ;
                   :location          "A1" ;
                   :sample_tube       :s3 .
          :tube4   :a                 :Tube ;
                   :location          "B1" ;
                   :sample_tube       :s4 .
        }
        @assets = SupportN3::parse_facts(facts)
        @rack2 = Asset.find_by(uuid: 'rack2')
        expect{@rack2.attributes_to_update}.to raise_exception Assets::Export::DuplicateLocations
      end

      it 'does not export locations without a sample in it' do
        facts = %Q{
          :s1 :a :SampleTube .
          :s2 :a :SampleTube .
          :s3 :a :SampleTube .
          :s4 :a :SampleTube .
          :rack2   :a                 :TubeRack ;
                   :contains          :tube1, :tube2, :tube3, :tube4 .

          :tube1   :a                 :Tube ;
                   :location          "A1" ;
                   :sample_tube       :s1 .
          :tube2   :a                 :Tube ;
                   :location          "B1" ;
                   :sample_tube       :s2 .
          :tube3   :a                 :Tube ;
                   :location          "C1" ;
                   :aliquotType       "DNA" .
          :tube4   :a                 :Tube ;
                   :location          "D1" ;
                   :sample_tube       :s4 .
        }
        @assets = SupportN3::parse_facts(facts)
        @rack2 = Asset.find_by(uuid: 'rack2')
        expect(@rack2.attributes_to_update).to eq([
          {sample_tube_uuid: "s1", location: "A1"},
          {sample_tube_uuid: "s2", location: "B1"},
          {sample_tube_uuid: "s4", location: "D1"}])
      end
    end
  end
end
