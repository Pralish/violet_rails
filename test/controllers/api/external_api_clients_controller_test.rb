require "test_helper"

class Api::ExternalApiClientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @external_api_client = external_api_clients(:webhook_drive_strategy)
    @api_namespace = @external_api_client.api_namespace
  end

  test '#webhook: should return success response if webhook verification not required' do
    post api_external_api_client_webhook_url(version: @api_namespace.version, api_namespace: @api_namespace.slug, external_api_client: @external_api_client.slug), params: {},  as: :json
    assert_response :success
  end

  test '#webhook: route should not exist if drive strategy id not webhook' do
    @external_api_client.update(drive_strategy: 'on_demand')
    assert_raises ActionController::RoutingError do
      post api_external_api_client_webhook_url(version: @api_namespace.version, api_namespace: @api_namespace.slug, external_api_client: @external_api_client.slug), params: {},  as: :json
    end
  end

  test '#webhook: should return error unless api client is enabled' do
    @external_api_client.update(enabled: false)
    post api_external_api_client_webhook_url(version: @api_namespace.version, api_namespace: @api_namespace.slug, external_api_client: @external_api_client.slug), params: {},  as: :json
    assert_response 400
    assert_equal({ 'message' => 'Webhook not enabled', 'success' => false }, JSON.parse(response.body))
  end

  test '#webhook - stripe: should return success response if webhook verification required and webhook verfied' do
    WebhookVerificationMethod.create(webhook_type: 'stripe', external_api_client_id: @external_api_client.id, webhook_secret: 'secret')
    Webhook::Verification.any_instance.stubs(:call).returns([true, 'success'])

    assert_difference "@api_namespace.api_resources.reload.count", +1 do
      post api_external_api_client_webhook_url(version: @api_namespace.version, api_namespace: @api_namespace.slug, external_api_client: @external_api_client.slug), params: { type: 'customer.created' },  as: :json
      Sidekiq::Worker.drain_all
    end
    assert_response :success

    assert_no_difference "@api_namespace.api_resources.reload.count" do
      post api_external_api_client_webhook_url(version: @api_namespace.version, api_namespace: @api_namespace.slug, external_api_client: @external_api_client.slug), params: { type: 'customer.removed' },  as: :json
      Sidekiq::Worker.drain_all
    end
    assert_response :success
  end

  test '#webhook - stripe: should return error response if webhook verification required and webhook verfication failed' do
    WebhookVerificationMethod.create(webhook_type: 'stripe', external_api_client_id: @external_api_client.id, webhook_secret: 'secret')
    Webhook::Verification.any_instance.stubs(:call).returns([false, 'error message'])

    post api_external_api_client_webhook_url(version: @api_namespace.version, api_namespace: @api_namespace.slug, external_api_client: @external_api_client.slug), params: {},  as: :json

    assert_response 400
    assert_equal({ 'message' => 'error message', 'success' => false }, JSON.parse(response.body))
  end

  test '#webhook - custom: should return success response if webhook verification required and webhook verified' do
    WebhookVerificationMethod.create(
      webhook_type: 'custom',
      external_api_client_id: @external_api_client.id,
      webhook_secret: 'secret',
      custom_method_definition: "
      if request.headers['Authorization'] == verification_method.webhook_secret
        [true, 'Verification Success']
      else
        [false, 'Invalid Authorization Token']
      end"
    )

    assert_difference "@api_namespace.api_resources.reload.count", +1 do
      post api_external_api_client_webhook_url(version: @api_namespace.version, api_namespace: @api_namespace.slug, external_api_client: @external_api_client.slug), params: { type: 'customer.created' }, headers: { 'Authorization': 'secret' }, as: :json
      Sidekiq::Worker.drain_all
    end
    assert_response :success

    assert_no_difference "@api_namespace.api_resources.reload.count" do
      post api_external_api_client_webhook_url(version: @api_namespace.version, api_namespace: @api_namespace.slug, external_api_client: @external_api_client.slug), params: { type: 'customer.removed' }, headers: { 'Authorization': 'secret' }, as: :json
      Sidekiq::Worker.drain_all
    end
    assert_response :success
  end


  test '#webhook - custom: should return error response if webhook verification required and webhook verfication failed' do
    WebhookVerificationMethod.create(
      webhook_type: 'custom',
      external_api_client_id: @external_api_client.id,
      webhook_secret: 'secret',
      custom_method_definition: "
      if request.headers['Authorization'] == verification_method.webhook_secret
        [true, 'Verification Success']
      else
        [false, 'Invalid Authorization Token']
      end"
    )

    post api_external_api_client_webhook_url(version: @api_namespace.version, api_namespace: @api_namespace.slug, external_api_client: @external_api_client.slug), params: {}, headers: { 'Authorization': 'not secret' }, as: :json

    assert_response 400
    assert_equal({ 'message' => 'Invalid Authorization Token', 'success' => false }, JSON.parse(response.body))
  end
end