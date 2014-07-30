require_relative './instance.rb'

class ListenerInstance < Instance
  include Celluloid
  attr_accessor :web_hooks, :service_id

  def initialize(options={})
    @web_hooks={}
    super(options)
  end

  def start(params)
    @params=params

    begin
      self.instance_exec @params, &@definition.start
      respond type:'started'
    rescue FactorConnectorError => ex
      error ex.message
      respond type:'fail' if ex.stopped?
      respond type:'started' if ex.started?
      exception ex.exception, params:@params if ex.exception
    rescue => ex
      error "Couldn't start listener for unexpected reason. We've been informed and looking into it."
      respond type:'fail'
      exception ex, params:@params
    end
  end

  def stop
    begin
      self.instance_exec @params, &@definition.stop
      respond type:'stopped'
    rescue FactorConnectorError => ex
      error ex.message
      respond type:'stopped' if ex.stopped?
      respond type:'fail' if ex.started?
      exception ex.exception, params:@params if ex.exception
    rescue ex
      error "Couldn't stop listener for unexpected reason. We've been informed and looking into it."
      respond type:'fail'
      exception ex, params:@params
    end
  end

  def start_workflow(params)
    @callback.call({:type=>'start_workflow',:payload=>params}) if @callback
  end

  def call_web_hook(web_hook_id,hook_params,request,response)
    web_hook=@web_hooks[web_hook_id]
    begin
      self.instance_exec @params, hook_params,request,response, &web_hook.start
    rescue FactorConnectorError => ex
      error ex.message
      exception ex.exception, params:hook_params, hook_id:web_hook_id if ex.exception
    rescue => ex
      error "Couldn't call webhook for unexpected reason. We've been informed and looking into it."
      exception ex, params:@params
    end
  end

  def web_hook(vals={},&block)
    web_hook=WebHookBuilder.new(vals,&block).build
    @web_hooks[web_hook.id]=web_hook
    hook_url(@service_id,self.id,@instance_id,web_hook.id)
  end

  def get_web_hook(web_hook_id)
    hook_url(@service_id,self.id,@instance_id,web_hook_id)
  end

  def fail(message,params={})
    raise FactorConnectorError, exception:params[:exception], message:message
  end

  private

  def hook_url(service_id,listener_id,instance_id,web_hook_id)
    path="v0.3/#{service_id}/listeners/#{listener_id}/instances/#{instance_id}/hooks/#{web_hook_id}"
    hook_url="https://connector.factor.io/#{path}"
    hook_url="#{ENV['LISTENER_DEV_URI']}/#{path}" if ENV['LISTENER_DEV_URI']
    hook_url
  end
end