class AuthenticationsController < ApplicationController
  def create
    omniauth = request.env['omniauth.auth']
    authentication = Authentication.find_by_provider_and_uid(omniauth['provider'], omniauth['uid'])

    if authentication
      # User is already registered with application
      flash[:info] = 'Signed in successfully.'
      sign_in_and_redirect(authentication.user)
    elsif user = current_user || User.find_by_email(omniauth['uid'] + "@utor.ca"); #User.find_by_email(omniauth['user_info']['email'])
      # User is signed in but has not already authenticated with this social network
      # OR
      #user already has a local account - connect it properly to an authentication
      user.authentications.create!(:provider => omniauth['provider'], :uid => omniauth['uid'])
      user.apply_omniauth(omniauth)
      user.save
      flash[:info] = 'Authentication successful.'
      redirect_to root_url
    else
      # User is new to this application
      user = User.new
      user.apply_omniauth(omniauth)
      if user.save
        flash[:info] = 'User created and signed in successfully.'
        user.authentications.create(:provider => omniauth['provider'], :uid => omniauth['uid'])
        user.activate
        sign_in_and_redirect_new_user(user)
      else
        session[:omniauth] = omniauth.except('extra')
        redirect_to signup_path
      end
    end
  end

  def destroy
    @authentication = current_user.authentications.find(params[:id])
    @authentication.destroy
    flash[:notice] = 'Successfully destroyed authentication.'
    redirect_to authentications_url
  end

  private
  def sign_in_and_redirect(user)
    unless current_user
      user_session = UserSession.new(user)
      user_session.save
    end
    redirect_to root_url
  end

  def sign_in_and_redirect_new_user(user)
    unless current_user
      user_session = UserSession.new(user)
      user_session.save
    end
    redirect_to edit_user_path(user) #root_url
  end

end
