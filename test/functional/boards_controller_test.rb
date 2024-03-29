# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../test_helper', __FILE__)

class BoardsControllerTest < ActionController::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles, :boards, :messages, :enabled_modules

  def setup
    User.current = nil
  end

  def test_index
    get :index, :project_id => 1
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:boards)
    assert_not_nil assigns(:project)
  end

  def test_index_not_found
    get :index, :project_id => 97
    assert_response 404
  end

  def test_index_should_show_messages_if_only_one_board
    Project.find(1).boards.slice(1..-1).each(&:destroy)

    get :index, :project_id => 1
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:topics)
  end

  def test_show
    get :show, :project_id => 1, :id => 1
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:board)
    assert_not_nil assigns(:project)
    assert_not_nil assigns(:topics)
  end

  def test_show_with_permission_should_display_the_new_message_form
    @request.session[:user_id] = 2
    get :show, :project_id => 1, :id => 1
    assert_response :success
    assert_template 'show'

    assert_tag 'form', :attributes => {:id => 'message-form'}
    assert_tag 'input', :attributes => {:name => 'message[subject]'}
  end

  def test_show_atom
    get :show, :project_id => 1, :id => 1, :format => 'atom'
    assert_response :success
    assert_template 'common/feed.atom'
    assert_not_nil assigns(:board)
    assert_not_nil assigns(:project)
    assert_not_nil assigns(:messages)
  end

  def test_show_not_found
    get :index, :project_id => 1, :id => 97
    assert_response 404
  end

  def test_new
    @request.session[:user_id] = 2
    get :new, :project_id => 1
    assert_response :success
    assert_template 'new'
  end

  def test_create
    @request.session[:user_id] = 2
    assert_difference 'Board.count' do
      post :create, :project_id => 1, :board => { :name => 'Testing', :description => 'Testing board creation'}
    end
    assert_redirected_to '/projects/ecookbook/settings/boards'
    board = Board.first(:order => 'id DESC')
    assert_equal 'Testing', board.name
    assert_equal 'Testing board creation', board.description
  end

  def test_create_with_failure
    @request.session[:user_id] = 2
    assert_no_difference 'Board.count' do
      post :create, :project_id => 1, :board => { :name => '', :description => 'Testing board creation'}
    end
    assert_response :success
    assert_template 'new'
  end

  def test_edit
    @request.session[:user_id] = 2
    get :edit, :project_id => 1, :id => 2
    assert_response :success
    assert_template 'edit'
  end

  def test_update
    @request.session[:user_id] = 2
    assert_no_difference 'Board.count' do
      put :update, :project_id => 1, :id => 2, :board => { :name => 'Testing', :description => 'Testing board update'}
    end
    assert_redirected_to '/projects/ecookbook/settings/boards'
    assert_equal 'Testing', Board.find(2).name
  end

  def test_update_with_failure
    @request.session[:user_id] = 2
    put :update, :project_id => 1, :id => 2, :board => { :name => '', :description => 'Testing board update'}
    assert_response :success
    assert_template 'edit'
  end

  def test_destroy
    @request.session[:user_id] = 2
    assert_difference 'Board.count', -1 do
      delete :destroy, :project_id => 1, :id => 2
    end
    assert_redirected_to '/projects/ecookbook/settings/boards'
    assert_nil Board.find_by_id(2)
  end
end
