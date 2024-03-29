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

class VersionsController < ApplicationController
  menu_item :roadmap
  model_object Version
  before_filter :find_model_object, :except => [:index, :new, :create, :close_completed]
  before_filter :find_project_from_association, :except => [:index, :new, :create, :close_completed]
  before_filter :find_project, :only => [:index, :new, :create, :close_completed]
  before_filter :authorize

  accept_api_auth :index, :show, :create, :update, :destroy

  helper :custom_fields
  helper :projects

  def index
    respond_to do |format|
      format.html {
        @trackers = @project.trackers.find(:all, :order => 'position')
        retrieve_selected_tracker_ids(@trackers, @trackers.select {|t| t.is_in_roadmap?})
        @with_subprojects = params[:with_subprojects].nil? ? Setting.display_subprojects_issues? : (params[:with_subprojects] == '1')
        project_ids = @with_subprojects ? @project.self_and_descendants.collect(&:id) : [@project.id]

        @versions = @project.shared_versions || []
        @versions += @project.rolled_up_versions.visible if @with_subprojects
        @versions = @versions.uniq.sort
        unless params[:completed]
          @completed_versions = @versions.select {|version| version.closed? || version.completed? }
          @versions -= @completed_versions
        end

        @issues_by_version = {}
        unless @selected_tracker_ids.empty?
          @versions.each do |version|
            issues = version.fixed_issues.visible.find(:all,
                                                       :include => [:project, :status, :tracker, :priority],
                                                       :conditions => {:tracker_id => @selected_tracker_ids, :project_id => project_ids},
                                                       :order => "#{Project.table_name}.lft, #{Tracker.table_name}.position, #{Issue.table_name}.id")
            @issues_by_version[version] = issues
          end
        end
        @versions.reject! {|version| !project_ids.include?(version.project_id) && @issues_by_version[version].blank?}
      }
      format.api {
        @versions = @project.shared_versions.all
      }
    end
  end

  def show
    respond_to do |format|
      format.html {
        @issues = @version.fixed_issues.visible.find(:all,
          :include => [:status, :tracker, :priority],
          :order => "#{Tracker.table_name}.position, #{Issue.table_name}.id")
      }
      format.api
    end
  end

  def new
    @version = @project.versions.build(params[:version])

    respond_to do |format|
      format.html
      format.js do
        render :update do |page|
          page.replace_html 'ajax-modal', :partial => 'versions/new_modal'
          page << "showModal('ajax-modal', '600px');"
          page << "Form.Element.focus('version_name');"
        end
      end
    end
  end

  def create
    @version = @project.versions.build
    if params[:version]
      attributes = params[:version].dup
      attributes.delete('sharing') unless attributes.nil? || @version.allowed_sharings.include?(attributes['sharing'])
      @version.attributes = attributes
    end

    if request.post?
      if @version.save
        respond_to do |format|
          format.html do
            flash[:notice] = l(:notice_successful_create)
            redirect_back_or_default :controller => 'projects', :action => 'settings', :tab => 'versions', :id => @project
          end
          format.js do
            render(:update) {|page|
              page << 'hideModal();'
              # IE doesn't support the replace_html rjs method for select box options
              page.replace "issue_fixed_version_id",
                content_tag('select', content_tag('option') + version_options_for_select(@project.shared_versions.open, @version), :id => 'issue_fixed_version_id', :name => 'issue[fixed_version_id]')
            }
          end
          format.api do
            render :action => 'show', :status => :created, :location => version_url(@version)
          end
        end
      else
        respond_to do |format|
          format.html { render :action => 'new' }
          format.js do
            render :update do |page|
              page.replace_html 'ajax-modal', :partial => 'versions/new_modal'
              page << "Form.Element.focus('version_name');"
            end
          end
          format.api  { render_validation_errors(@version) }
        end
      end
    end
  end

  def edit
  end

  def update
    if request.put? && params[:version]
      attributes = params[:version].dup
      attributes.delete('sharing') unless @version.allowed_sharings.include?(attributes['sharing'])
      if @version.update_attributes(attributes)
        respond_to do |format|
          format.html {
            flash[:notice] = l(:notice_successful_update)
            redirect_back_or_default :controller => 'projects', :action => 'settings', :tab => 'versions', :id => @project
          }
          format.api  { head :ok }
        end
      else
        respond_to do |format|
          format.html { render :action => 'edit' }
          format.api  { render_validation_errors(@version) }
        end
      end
    end
  end

  def close_completed
    if request.put?
      @project.close_completed_versions
    end
    redirect_to :controller => 'projects', :action => 'settings', :tab => 'versions', :id => @project
  end

  verify :method => :delete, :only => :destroy, :render => {:nothing => true, :status => :method_not_allowed }
  def destroy
    if @version.fixed_issues.empty?
      @version.destroy
      respond_to do |format|
        format.html { redirect_back_or_default :controller => 'projects', :action => 'settings', :tab => 'versions', :id => @project }
        format.api  { head :ok }
      end
    else
      respond_to do |format|
        format.html {
          flash[:error] = l(:notice_unable_delete_version)
          redirect_to :controller => 'projects', :action => 'settings', :tab => 'versions', :id => @project
        }
        format.api  { head :unprocessable_entity }
      end
    end
  end

  def status_by
    respond_to do |format|
      format.html { render :action => 'show' }
      format.js { render(:update) {|page| page.replace_html 'status_by', render_issue_status_by(@version, params[:status_by])} }
    end
  end

private
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def retrieve_selected_tracker_ids(selectable_trackers, default_trackers=nil)
    if ids = params[:tracker_ids]
      @selected_tracker_ids = (ids.is_a? Array) ? ids.collect { |id| id.to_i.to_s } : ids.split('/').collect { |id| id.to_i.to_s }
    else
      @selected_tracker_ids = (default_trackers || selectable_trackers).collect {|t| t.id.to_s }
    end
  end

end
