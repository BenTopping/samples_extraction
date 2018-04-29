class AssetGroupsController < ApplicationController
  before_action :set_asset_group, only: [:show, :update, :print, :upload]
  before_action :set_activity, only: [:show, :update]
  before_action :update_barcodes, only: [:update]

  include ActionController::Live

  include ActivitiesHelper

  def show
    @assets = @asset_group.assets
    @assets_grouped = assets_by_fact_group

    respond_to do |format|
      format.html { render @asset_group }
      format.n3 { render :show }
      format.json { head :ok}
    end
  end


  def update
    @assets = @asset_group.assets
    @assets_grouped = assets_by_fact_group

    head :ok
  end

  def upload
    @file = UploadedFile.create(filename: params[:qqfilename], data: params[:qqfile].read)
    asset = @file.build_asset
    @asset_group.assets << asset
    @asset_group.touch

    render json: {success: true}
  end

  def print
    @asset_group.print(@current_user.printer_config, @current_user.username)

    redirect_to :back
  end

  private

    def update_barcodes
      perform_assets_update
      perform_barcode_addition

      if @alerts
        render json: {errors: @alerts}
      end
    end

    def assets_by_fact_group
      obj_type = Struct.new(:predicate,:object,:to_add_by, :to_remove_by, :object_asset_id)
      @assets.group_by do |a|
        a.facts.map(&:as_json).map do |f|
          obj_type.new(f["predicate"], f["object"])
        end
      end
    end


    def set_activity
      # I need the activity to be able to know the step_types compatible to show.
      @activity = Activity.find(params[:activity_id]) if params[:activity_id]
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_asset_group
      @asset_group = AssetGroup.find(params[:id])
    end

  def perform_assets_update
    if params_update_asset_group[:assets]
      updated_assets = [params_update_asset_group[:assets]].flatten
      received_list = updated_assets.map{|uuid| Asset.find_by!(uuid: uuid)}
      @asset_group.update_attributes(assets: received_list)
      @asset_group.touch
    end
  end

  def show_alert(data)
    @alerts = [] unless @alerts
    @alerts.push(data)
  end

  def get_barcodes
    params_update_asset_group[:add_barcodes].split(' ')
  end

  def perform_barcode_addition
    unless params_update_asset_group[:add_barcodes].nil? || params_update_asset_group[:add_barcodes].empty?
      begin
        if @asset_group.select_barcodes(get_barcodes)
          @asset_group.touch
          puts 1
          #show_alert({:type => 'info',
          #  :msg => "Barcode #{get_barcodes} added"})
        else
          show_alert({:type => 'warning',
            :msg => "Cannot select #{get_barcodes}"})
          #flash[:danger] = "Could not find barcodes #{barcodes}"
        end
      rescue Net::ReadTimeout => e
        show_alert({:type => 'danger',
          :msg => "Cannot connect with Sequencescape for reading barcode #{get_barcodes}"})
      rescue Sequencescape::Api::ResourceNotFound => e
        show_alert({:type => 'warning',
          :msg => "Cannot find barcode #{get_barcodes} in Sequencescape"})
      rescue StandardError => e
        show_alert({:type => 'danger',
          :msg => "Cannot connect with Sequencescape: Message: #{e.message}"})
      end
    end
  end

  def params_update_asset_group
    params.require(:asset_group).permit(:add_barcodes, :assets => [])
  end

end
