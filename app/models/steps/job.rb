module Steps::Job

  def asset_group_for_execution
    asset_group
    #AssetGroup.create!(:assets => asset_group.assets)
  end

  def execute_actions
    update_attributes!({
      :state => 'running',
      :step_type => step_type,
    })
    update_attributes!({
      job_id: delay.perform_job.id
    })
  end

  def output_error(exception)
    return output unless exception
    [output, exception && exception.message, Rails.backtrace_cleaner.clean(exception && exception.backtrace)].flatten.join("\n")
  end

  def job
    job_id ? Delayed::Job.find(job_id) : nil
  end

  def perform_job
    return if cancelled? || stopped?
    assign_attributes(state: 'running', output: nil)
    @error = nil
    begin
      process
    rescue StandardError => e
      @error = e
    else
      @error=nil
      update_attributes!(:state => 'complete', job_id: nil)
    end
  ensure
    # We publish to the clients that there has been a change in these assets
    asset_group.touch
    if activity
      activity.asset_group.touch unless state == 'complete'
    end

    # TODO:
    # This update needs to happen AFTER publishing the changes to the clients (touch), although
    # is not clear for me why at this moment. Need to revisit it.
    unless state == 'complete'
      update_attributes!(:state => 'error', output: output_error(@error), job_id: job ? job.id : nil)
    end
  end

end