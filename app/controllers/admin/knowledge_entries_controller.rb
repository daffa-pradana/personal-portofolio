module Admin
  class KnowledgeEntriesController < BaseController
    before_action :set_knowledge_entry, only: %i[ edit update destroy ]

    def index
      @knowledge_entries = KnowledgeEntry.ordered
    end

    def new
      @knowledge_entry = KnowledgeEntry.new
    end

    def create
      @knowledge_entry = KnowledgeEntry.new(knowledge_entry_params)

      if @knowledge_entry.save
        redirect_to admin_knowledge_entries_path, notice: "Knowledge entry created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @knowledge_entry.update(knowledge_entry_params)
        redirect_to admin_knowledge_entries_path, notice: "Knowledge entry updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @knowledge_entry.destroy
      redirect_to admin_knowledge_entries_path, notice: "Knowledge entry deleted.", status: :see_other
    end

    private
      def set_knowledge_entry
        @knowledge_entry = KnowledgeEntry.find(params[:id])
      end

      def knowledge_entry_params
        params.expect(knowledge_entry: [ :category, :title, :content, :position ])
      end
  end
end
