import SwiftUI

struct ProjectListView: View {
    @StateObject private var controller = ProjectListViewController()
    @State private var showingRenameAlert = false
    @State private var showingCreateAlert = false
    @State private var projectToRename: ProjectInfo?
    @State private var newProjectName = ""
    @State private var createProjectName = ""
    @State private var selectedProject: ProjectInfo?
    @State private var showMainPage = false
    
    var body: some View {
        NavigationStack {  // Changed from NavigationView to NavigationStack
            VStack(spacing: 0) {
                // Custom header with title and plus button aligned
                HStack {
                    Text("Projects")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        createProjectName = ""
                        showingCreateAlert = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 25)
                
                // Main content
                mainContent
            }
            .navigationBarHidden(true)  // Hide the default navigation bar
            .navigationDestination(isPresented: $showMainPage) { 
                mainPageDestination 
            }
            .alert("Rename Project", isPresented: $showingRenameAlert) { 
                renameAlertContent 
            }
            .alert("Create New Project", isPresented: $showingCreateAlert) { 
                createAlertContent 
            }
        }
    }
    
    // MARK: - Sub-views
    
    private var mainContent: some View {
        VStack {
            if controller.projects.isEmpty {
                emptyStateView
            } else {
                projectsListView
            }
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
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
    }
    
    private var projectsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sortedProjects, id: \.id) { project in
                    ProjectRowView(
                        project: project,
                        onTap: {
                            selectedProject = project
                            showMainPage = true
                        },
                        onRename: {
                            projectToRename = project
                            newProjectName = project.name
                            showingRenameAlert = true
                        },
                        onDelete: {
                            controller.deleteProject(project)
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }
    
    private var sortedProjects: [ProjectInfo] {
        Array(controller.projects.values).sorted { $0.createdDate > $1.createdDate }
    }
    
    @ViewBuilder
    private var mainPageDestination: some View {
        if let project = selectedProject {
            MainPage(project: project)
                .toolbar(.hidden, for: .navigationBar)  // Modern way to hide navigation bar
        }
    }
    
    private var renameAlertContent: some View {
        Group {
            TextField("Project Name", text: $newProjectName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let project = projectToRename {
                    controller.renameProject(projectId: project.id, to: newProjectName)
                }
            }
        }
    }
    
    private var createAlertContent: some View {
        Group {
            TextField("Project name (optional)", text: $createProjectName)
            Button("Cancel", role: .cancel) {
                createProjectName = ""
            }
            Button("Create") {
                let finalName = createProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                _ = controller.createNewProject(name: finalName)
                createProjectName = ""
            }
        }
    }
}

struct ProjectRowView: View {
    let project: ProjectInfo
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            rowContent
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            contextMenuContent
        }
    }
    
    private var rowContent: some View {
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
    
    private var contextMenuContent: some View {
        Group {
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    ProjectListView()
}
