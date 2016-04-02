/*
* Copyright (c) 2015 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import Foundation
import ReactiveKit

class PhotoSearchViewModel {
  
  // Metadata from Settings screen.
  let searchMetadataViewModel = PhotoSearchMetadataViewModel()
  
  let searchString = Observable<String?>("")
  let searchResults = ObservableCollection<[Photo]>([])
  
  let validSearchText = Observable<Bool>(false)
  let searchInProgress = Observable<Bool>(false)
  
  // FIXME: implement equivalent of Bond's EventProducer<String>()
  let errorMessages = Observable<String?>("")
  
  
  private let searchService: PhotoSearch = {
    let apiKey = NSBundle.mainBundle().objectForInfoDictionaryKey("apiKey") as! String
    return PhotoSearch(key: apiKey)
  }()
  
  
  init() {
    searchString.value = "Bond"
    
    searchString
      .map { $0?.characters.count > 3 }
      .bindTo(validSearchText)
    
    searchString
      .filter { $0?.characters.count > 3 }
      .throttle(0.5, on: Queue.main)
      .observe { [unowned self] text in
        self.executeSearch(text!)
    }
    
    // Observe if setting in the Settings screen changes. If yes, search.
    combineLatest(
      searchMetadataViewModel.dateFilter,
      searchMetadataViewModel.minUploadDate,
      searchMetadataViewModel.maxUploadDate,
      searchMetadataViewModel.creativeCommons
      ).throttle(0.5, on: Queue.main)
      .observe { [unowned self] text in
        self.executeSearch(self.searchString.value!)
    }
  }
  
  func executeSearch(text: String) {
    var query = PhotoQuery()
    query.text = searchString.value ?? ""
    query.creativeCommonsLicence = searchMetadataViewModel.creativeCommons.value
    query.dateFilter = searchMetadataViewModel.dateFilter.value
    query.minDate = searchMetadataViewModel.minUploadDate.value
    query.maxDate = searchMetadataViewModel.maxUploadDate.value
    
    searchInProgress.value = true
    
    searchService.findPhotos(query) { result in
      // async search completed
      self.searchInProgress.value = false
      
      switch result {
      case .Success(let photos):
        print("500px API returned \(photos.count) photos")
        self.searchResults.removeAll()
        self.searchResults.insertContentsOf(photos, at: 0)
      case .Error:
        print("Sad face :-(")
        self.errorMessages.next("There was an API issue. Sad face :-(")
      }
    }
  }
  
  
}
