class StepTypesController < ApplicationController
  before_action :set_step_type, only: [:show, :edit, :update, :destroy]
  before_action :set_activity, only: [:active]

  before_action :nested_step_types, only: [:index]

  def nested_step_types
    if step_type_params[:activity_id]
      @activity = Activity.find(step_type_params[:activity_id])
      @step_types = @activity.step_types_active
    else
      @step_types = StepType.all
    end
  end

  # GET /step_types
  # GET /step_types.json
  def index
    @step_types = StepType.all unless @activity
    respond_to do |format|
      format.html { render 'active', :layout => false } if @activity
      format.html { render 'index' }
    end
  end

  # GET /step_types/1
  # GET /step_types/1.json
  def show
  end

  # GET /step_types/new
  def new
    @step_type = StepType.new
  end

  # GET /step_types/1/edit
  def edit
  end

  def active
    @assets = @activity.asset_group.assets
    @step_types = @activity.step_types_for(@assets)

    respond_to do |format|
      format.html {
        render 'steps/_active', :locals => {
          :step_types => @step_types,
          :activity => @activity
        }, :layout => false
      }
    end
  end

  # POST /step_types
  # POST /step_types.json
  def create
    @step_type = StepType.new(step_type_params)

    respond_to do |format|
      if @step_type.save
        format.html { redirect_to @step_type, notice: 'Step type was successfully created.' }
        format.json { render :show, status: :created, location: @step_type }
      else
        format.html { render :new }
        format.json { render json: @step_type.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /step_types/1
  # PATCH/PUT /step_types/1.json
  def update
    respond_to do |format|
      if @step_type.update(step_type_params_for_update)
        format.html { redirect_to @step_type, notice: 'Step type was successfully updated.' }
        format.json { render :show, status: :ok, location: @step_type }
      else
        format.html { render :edit }
        format.json { render json: @step_type.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /step_types/1
  # DELETE /step_types/1.json
  def destroy
    @step_type.destroy
    respond_to do |format|
      format.html { redirect_to step_types_url, notice: 'Step type was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_step_type
      @step_type = StepType.find(params[:id])
    end

    def set_activity
      @activity = Activity.find(params[:activity_id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def step_type_params
      params.permit(:activity_id, :id, :name, :n3_definition, :step_template)
    end

    def step_type_params_for_update
      params.require(:step_type).permit(:n3_definition,:name, :step_template)
    end


end
