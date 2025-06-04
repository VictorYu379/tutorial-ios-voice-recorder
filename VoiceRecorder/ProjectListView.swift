import SwiftUI

struct ProjectListView: View {
    @StateObject private var projectManager = ProjectManager()
    @State private var showingRenameAlert = false
    @State private var projectToRename: Project?
    @State private var newProjectName = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if projectManager.projects.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Projects Yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Create your first project to get started")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Projects list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(projectManager.projects) { project in
                                ProjectRowView(
                                    project: project,
                                    onRename: {
                                        projectToRename = project
                                        newProjectName = project.name
                                        showingRenameAlert = true
                                    },
                                    onDelete: {
                                        projectManager.deleteProject(project)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Projects")
            .navigationBarItems(
                trailing: Button(action: {
                    _ = projectManager.createNewProject()
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            )
            .alert("Rename Project", isPresented: $showingRenameAlert) {
                TextField("Project Name", text: $newProjectName)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    if let project = projectToRename {
                        projectManager.renameProject(project, to: newProjectName)
                    }
                }
            } message: {
                Text("Enter a new name for your project")
            }
        }
    }
}

struct ProjectRowView: View {
    let project: Project
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        NavigationLink(destination: MainPage()) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Modified: \(project.formattedDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(action: onDelete, role: .destructive) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    ProjectListView()
}
