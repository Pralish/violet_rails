class Comfy::Admin::ApiActionsController < Comfy::Admin::Cms::BaseController
  before_action :ensure_authority_to_manage_api
  before_action :set_api_action, except: :new

  def new
    @index = params[:index]
    @type = params[:type]
    @api_action = ApiAction.new(type: params[:type].classify, position: @index)
    
    respond_to do |format|
      format.js
    end
  end

  def index
    params[:q] ||= {}
    @api_actions_q = @api_namespace.executed_api_actions.order(created_at: :desc).ransack(params[:q])
    @api_actions = @api_actions_q.result.paginate(page: params[:page], per_page: 10)
  end

  def show
  end

  def action_workflow
    
  end

  private

  def set_api_action
    @api_namespace = ApiNamespace.find_by(id: params[:api_namespace_id])
    @api_action = @api_namespace.executed_api_actions.find_by(id: params[:id])
  end
end