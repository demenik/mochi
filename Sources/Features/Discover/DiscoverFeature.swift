//
//  DiscoverFeature.swift
//
//
//  Created by ErrorErrorError on 4/5/23.
//
//

import Architecture
import ComposableArchitecture
import Foundation
import LocalizableClient
import ModuleClient
import ModuleLists
import OrderedCollections
import PlaylistDetails
import RepoClient
import Search
import SharedModels
import Styling
import SwiftUI
import ViewComponents

// MARK: - DiscoverFeature

public struct DiscoverFeature: Feature {
  public enum Error: Swift.Error, Equatable, Sendable, Localizable {
    case system(System)
    case module(ModuleClient.Error)

    public enum System: Equatable, Sendable {
      case unknown
      case moduleNotSelected
    }

    public var localizable: String {
      switch self {
      case .system(.moduleNotSelected):
        .init(localizable: "There is no module selected")
      case .system(.unknown):
        .init(localizable: "Unknown system error has occurred")
      case .module:
        .init(localizable: "Failed to load module listings")
      }
    }
  }

  public struct Path: Reducer {
    @CasePathable
    @dynamicMemberLookup
    public enum State: Equatable, Sendable {
      case search(SearchFeature.State)
      case playlistDetails(PlaylistDetailsFeature.State)
      case viewMoreListing(ViewMoreListing.State)
    }

    @CasePathable
    @dynamicMemberLookup
    public enum Action: Equatable, Sendable {
      case search(SearchFeature.Action)
      case playlistDetails(PlaylistDetailsFeature.Action)
      case viewMoreListing(ViewMoreListing.Action)
    }

    @ReducerBuilder<State, Action> public var body: some ReducerOf<Self> {
      Scope(state: \.search, action: \.search) {
        SearchFeature()
      }

      Scope(state: \.playlistDetails, action: \.playlistDetails) {
        PlaylistDetailsFeature()
      }

      Scope(state: \.viewMoreListing, action: \.viewMoreListing) {
        ViewMoreListing()
      }
    }
  }

  @CasePathable
  @dynamicMemberLookup
  public enum Section: Equatable, Sendable {
    case home(HomeState = .init())
    case module(ModuleListingState)

    var title: String {
      switch self {
      case .home:
        .init(localizable: "Home")
      case let .module(moduleState):
        moduleState.module.module.name
      }
    }

    var icon: URL? {
      switch self {
      case .home:
        nil
      case let .module(moduleState):
        moduleState.module.module.icon.flatMap { URL(string: $0) }
      }
    }

    public struct HomeState: Equatable, Sendable {
      public init() {}
    }

    public struct ModuleListingState: Equatable, Sendable {
      public var module: RepoClient.SelectedModule
      public var listings: Loadable<[DiscoverListing]>

      public init(
        module: RepoClient.SelectedModule,
        listings: Loadable<[DiscoverListing]>
      ) {
        self.module = module
        self.listings = listings
      }
    }
  }

  public struct State: FeatureState {
    public var section: Section
    public var path: StackState<Path.State>

    @PresentationState public var moduleLists: ModuleListsFeature.State?

    public init(
      section: DiscoverFeature.Section = .home(),
      path: StackState<Path.State> = .init(),
      moduleLists: ModuleListsFeature.State? = nil
    ) {
      self.section = section
      self.path = path
      self.moduleLists = moduleLists
    }
  }

  @CasePathable
  @dynamicMemberLookup
  public enum Action: FeatureAction {
    @CasePathable
    @dynamicMemberLookup
    public enum ViewAction: SendableAction {
      case didAppear
      case didTapOpenModules
      case didTapPlaylist(Playlist)
      case didTapSearchButton
      case didTapViewMoreListing(DiscoverListing.ID)
    }

    @CasePathable
    @dynamicMemberLookup
    public enum DelegateAction: SendableAction {
      case playbackVideoItem(
        Playlist.ItemsResponse,
        repoModuleId: RepoModuleID,
        playlist: Playlist,
        group: Playlist.Group.ID,
        variant: Playlist.Group.Variant.ID,
        paging: PagingID,
        itemId: Playlist.Item.ID
      )
    }

    @CasePathable
    public enum InternalAction: SendableAction {
      case selectedModule(RepoClient.SelectedModule?)
      case loadedListings(RepoModuleID, Loadable<[DiscoverListing]>)
      case moduleLists(PresentationAction<ModuleListsFeature.Action>)
      case path(StackAction<Path.State, Path.Action>)
    }

    case view(ViewAction)
    case delegate(DelegateAction)
    case `internal`(InternalAction)
  }

  @MainActor
  public struct View: FeatureView {
    public let store: StoreOf<DiscoverFeature>

    @Dependency(\.localizableClient.localize) var localize
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @MainActor
    public init(store: StoreOf<DiscoverFeature>) {
      self.store = store
    }
  }

  @Dependency(\.repoClient) var repoClient
  @Dependency(\.moduleClient) var moduleClient

  public init() {}
}
