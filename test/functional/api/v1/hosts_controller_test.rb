require 'test_helper'

class Api::V1::HostsControllerTest < ActionController::TestCase
  def setup
    @host = FactoryGirl.create(:host)
    @ptable = FactoryGirl.create(:ptable)
    @ptable.operatingsystems = [ Operatingsystem.find_by_name('Redhat') ]
  end

  def valid_attrs
    { :name                => 'testhost11',
      :environment_id      => environments(:production).id,
      :domain_id           => domains(:mydomain).id,
      :ip                  => '10.0.0.20',
      :mac                 => '52:53:00:1e:85:93',
      :ptable_id           => @ptable.id,
      :medium_id           => media(:one).id,
      :architecture_id     => Architecture.find_by_name('x86_64').id,
      :operatingsystem_id  => Operatingsystem.find_by_name('Redhat').id,
      :puppet_proxy_id     => smart_proxies(:puppetmaster).id,
      :compute_resource_id => compute_resources(:one).id,
      :root_pass           => "xybxa6JUkz63w",
      :location_id         => taxonomies(:location1).id,
      :organization_id     => taxonomies(:organization1).id
    }
  end

  test "should get index" do
    get :index, { }
    assert_response :success
    assert_not_nil assigns(:hosts)
    hosts = ActiveSupport::JSON.decode(@response.body)
    assert_not_empty hosts
  end

  test "should show individual record" do
    get :show, { :id => @host.to_param }
    assert_response :success
    show_response = ActiveSupport::JSON.decode(@response.body)
    assert_not_empty show_response
  end

  test "should create host" do
    disable_orchestration
    assert_difference('Host.count') do
      post :create, { :host => valid_attrs }
    end
    assert_response :success
  end

  test "should create host with host_parameters_attributes" do
    disable_orchestration
    Foreman::Deprecation.expects(:api_deprecation_warning).with('Field host_parameters_attributes.nested ignored')
    assert_difference('Host.count') do
      attrs = [{"name" => "compute_resource_id", "value" => "1", "nested" => "true"}]
      post :create, { :host => valid_attrs.merge(:host_parameters_attributes => attrs) }
    end
    assert_response :created
  end

  test "should create host with host_parameters_attributes sent in a hash" do
    disable_orchestration
    Foreman::Deprecation.expects(:api_deprecation_warning).with('Field host_parameters_attributes.nested ignored')
    assert_difference('Host.count') do
      attrs = {"0" => {"name" => "compute_resource_id", "value" => "1", "nested" => "true"}}
      post :create, { :host => valid_attrs.merge(:host_parameters_attributes => attrs) }
    end
    assert_response :created
  end

  test "should create host with managed is false if parameter is passed" do
    disable_orchestration
    post :create, { :host => valid_attrs.merge!(:managed => false) }
    assert_response :success
    last_host = Host.order('id desc').last
    assert_equal false, last_host.managed?
  end

  test "should update host" do
    put :update, { :id => @host.to_param, :host => { :name => 'testhost1435' } }
    assert_response :success
  end

  test "should destroy hosts" do
    assert_difference('Host.count', -1) do
      delete :destroy, { :id => @host.to_param }
    end
    assert_response :success
  end

  test "should show status hosts" do
    Foreman::Deprecation.expects(:api_deprecation_warning).with(regexp_matches(%r{/status route is deprecated}))
    get :status, { :id => @host.to_param }
    assert_response :success
  end

  test "should be able to create hosts even when restricted" do
    disable_orchestration
    assert_difference('Host.count') do
      post :create, { :host => valid_attrs }
    end
    assert_response :success
  end

  test "should allow access to restricted user who owns the host" do
    host = FactoryGirl.create(:host, :owner => users(:restricted))
    setup_user 'view', 'hosts', "owner_type = User and owner_id = #{users(:restricted).id}", :restricted
    get :show, { :id => host.to_param }
    assert_response :success
  end

  test "should allow to update for restricted user who owns the host" do
    disable_orchestration
    host = FactoryGirl.create(:host, :owner => users(:restricted))
    setup_user 'edit', 'hosts', "owner_type = User and owner_id = #{users(:restricted).id}", :restricted
    put :update, { :id => host.to_param, :host => {:name => 'testhost1435'} }
    assert_response :success
  end

  test "should allow destroy for restricted user who owns the hosts" do
    host = FactoryGirl.create(:host, :owner => users(:restricted))
    assert_difference('Host.count', -1) do
      setup_user 'destroy', 'hosts', "owner_type = User and owner_id = #{users(:restricted).id}", :restricted
      delete :destroy, { :id => host.to_param }
    end
    assert_response :success
  end

  test "should allow show status for restricted user who owns the hosts" do
    host = FactoryGirl.create(:host, :owner => users(:restricted))
    setup_user 'view', 'hosts', "owner_type = User and owner_id = #{users(:restricted).id}", :restricted
    Foreman::Deprecation.expects(:api_deprecation_warning).with(regexp_matches(%r{/status route is deprecated}))
    get :status, { :id => host.to_param }
    assert_response :success
  end

  test "should not allow access to a host out of users hosts scope" do
    setup_user 'view', 'hosts', "owner_type = User and owner_id = #{users(:restricted).id}", :restricted
    get :show, { :id => @host.to_param }
    assert_response :not_found
  end

  test "should not list a host out of users hosts scope" do
    host = FactoryGirl.create(:host, :owner => users(:restricted))
    setup_user 'view', 'hosts', "owner_type = User and owner_id = #{users(:restricted).id}", :restricted
    get :index, {}
    assert_response :success
    hosts = ActiveSupport::JSON.decode(@response.body)
    ids = hosts.map { |hash| hash['host']['id'] }
    refute_includes ids, @host.id
    assert_includes ids, host.id
  end

  test "should not update host out of users hosts scope" do
    setup_user 'edit', 'hosts', "owner_type = User and owner_id = #{users(:restricted).id}", :restricted
    put :update, { :id => @host.to_param }
    assert_response :not_found
  end

  test "should not delete hosts out of users hosts scope" do
    setup_user 'destroy', 'hosts', "owner_type = User and owner_id = #{users(:restricted).id}", :restricted
    delete :destroy, { :id => @host.to_param }
    assert_response :not_found
  end

  test "should not show status of hosts out of users hosts scope" do
    setup_user 'view', 'hosts', "owner_type = User and owner_id = #{users(:restricted).id}", :restricted
    get :status, { :id => @host.to_param }
    assert_response :not_found
  end

  def set_remote_user_to(user)
    @request.env['REMOTE_USER'] = user.login
  end

  test "when REMOTE_USER is provided and both authorize_login_delegation{,_api}
        are set, authentication should succeed w/o valid session cookies" do
    Setting[:authorize_login_delegation] = true
    Setting[:authorize_login_delegation_api] = true
    set_remote_user_to users(:admin)
    User.current = nil # User.current is admin at this point (from initialize_host)
    host = Host.first
    get :show, {:id => host.to_param, :format => 'json'}
    assert_response :success
    get :show, {:id => host.to_param}
    assert_response :success
  end
end
