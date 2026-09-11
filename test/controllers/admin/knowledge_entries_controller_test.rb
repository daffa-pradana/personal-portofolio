require "test_helper"

class Admin::KnowledgeEntriesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as User.take }

  test "requires authentication" do
    sign_out

    get admin_knowledge_entries_path

    assert_redirected_to new_session_path
  end

  test "index lists entries ordered by position" do
    get admin_knowledge_entries_path

    assert_response :success
    assert_select "td", text: knowledge_entries(:stack).title
    assert_select "td", text: knowledge_entries(:unpositioned).title
  end

  test "new renders the form" do
    get new_admin_knowledge_entry_path

    assert_response :success
  end

  test "create with valid params" do
    assert_difference("KnowledgeEntry.count", 1) do
      post admin_knowledge_entries_path, params: {
        knowledge_entry: { category: "skills", title: "New skill", content: "Something new.", position: 5 }
      }
    end

    assert_redirected_to admin_knowledge_entries_path
  end

  test "create with invalid params re-renders the form" do
    assert_no_difference("KnowledgeEntry.count") do
      post admin_knowledge_entries_path, params: { knowledge_entry: { title: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "edit renders the form for an existing entry" do
    get edit_admin_knowledge_entry_path(knowledge_entries(:stack))

    assert_response :success
  end

  test "update changes the entry's attributes" do
    entry = knowledge_entries(:stack)

    patch admin_knowledge_entry_path(entry), params: { knowledge_entry: { content: "Updated content." } }

    assert_redirected_to admin_knowledge_entries_path
    assert_equal "Updated content.", entry.reload.content
  end

  test "update with blank title re-renders the form" do
    entry = knowledge_entries(:stack)

    patch admin_knowledge_entry_path(entry), params: { knowledge_entry: { title: "" } }

    assert_response :unprocessable_entity
    assert_equal "Tech stack", entry.reload.title
  end

  test "destroy removes the entry" do
    entry = knowledge_entries(:unpositioned)

    assert_difference("KnowledgeEntry.count", -1) do
      delete admin_knowledge_entry_path(entry)
    end

    assert_redirected_to admin_knowledge_entries_path
  end
end
