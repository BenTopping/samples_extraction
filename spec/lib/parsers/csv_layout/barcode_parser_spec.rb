require 'rails_helper'
require 'parsers/csv_layout/barcode_parser'
require 'parsers/csv_layout/validators/any_barcode_validator'
require 'parsers/csv_layout/validators/fluidx_barcode_validator'


RSpec.describe Parsers::CsvLayout::BarcodeParser do
  before do
    allow(Asset).to receive(:find_or_import_asset_with_barcode) do |barcode|
      Asset.find_by(barcode: barcode)
    end
  end
  let(:main_parser) {
    main = double('parser')
    allow(main).to receive(:add_error)
    allow(main).to receive(:components).and_return({
      barcode_validator: ValidatorSuccess
    })
    main
  }
  class ValidatorSuccess < ActiveModel::Validator
    def validate(record)
      true
    end
  end

  let(:barcode) { '1234' }
  let(:location) { 'A10'}
  let(:input) {[location, barcode]}
  context '#initialize' do
    let(:parser) { Parsers::CsvLayout::BarcodeParser.new(input, main_parser) }
    it 'can be initialized' do
      expect{parser.barcode}.not_to raise_error
    end
    it 'returns the barcode' do
      expect(parser.barcode).to eq(barcode)
    end
    it 'can parse a line' do
      expect(Parsers::CsvLayout::BarcodeParser.new(["A01","F123456"], main_parser).barcode).to eq("F123456")
    end
    it 'chomps empty spaces before and after the barcode' do
      expect(Parsers::CsvLayout::BarcodeParser.new(["A01","   F123456   "], main_parser).barcode).to eq("F123456")
    end
  end
  context 'when the asset exists' do
    before do
      create :asset, barcode: barcode
    end
    let(:parser) { Parsers::CsvLayout::BarcodeParser.new(input, main_parser) }
    it 'validates the instance' do
      expect(parser).to be_valid
    end
  end
  context 'when the asset does not exist' do
    let(:parser) { Parsers::CsvLayout::BarcodeParser.new(input, main_parser) }
    it 'does not validate the instance' do
      expect(parser).not_to be_valid
    end
  end

  context 'when a barcode validator is supplied' do
    before do
      create :asset, barcode: barcode
    end

    class ValidatorReject < ActiveModel::Validator
      def validate(record)
        record.errors.add(:barcode, 'There was an error')
        false
      end
    end
    let(:parser) { Parsers::CsvLayout::BarcodeParser.new(input, main_parser) }
    context 'when the validator accepts the input' do
      before do
        allow(main_parser).to receive(:components).and_return({
          barcode_validator: ValidatorSuccess
        })
      end
      it 'validates the instance' do
        expect(parser).to be_valid
      end
    end
    context 'when the validator rejects the input' do
      before do
        allow(main_parser).to receive(:components).and_return({
          barcode_validator: ValidatorReject
        })
      end

      it 'does not validate' do
        expect(parser).not_to be_valid
      end
    end
  end

  describe '#no_read_barcode?' do
    it 'validates no read strings' do
      expect(Parsers::CsvLayout::BarcodeParser.new(["B01", "NO READ"], main_parser).no_read_barcode?).to eq(true)
      expect(Parsers::CsvLayout::BarcodeParser.new(["B01","no read"], main_parser).no_read_barcode?).to eq(true)
      expect(Parsers::CsvLayout::BarcodeParser.new(["B01","No Read"], main_parser).no_read_barcode?).to eq(true)
      expect(Parsers::CsvLayout::BarcodeParser.new(["B01","adasdf"], main_parser).no_read_barcode?).to eq(false)
    end
  end
end
