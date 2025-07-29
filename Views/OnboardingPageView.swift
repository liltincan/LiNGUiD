import SwiftUI

struct OnboardingPageView: View {
    let index: Int

    var body: some View {
        //VStack{
            //Color.black.edgesIgnoringSafeArea(.all)
            //VStack(spacing: 00) {

                Group {
                    switch index {
                    case 0:
                        VStack{
                            Text("Let's get to know you")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 5)
                                .drawingGroup()
                            
                            Text("Select your native language(s)")
                                .font(.system(size: 17))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .drawingGroup()
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        
                        
                        
                    case 1:
                        VStack{
                            Text("Where are you from?")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 5)
                                .drawingGroup()
                            
                            Text("This step helps clarify dialectal differences")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .drawingGroup()
                            
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        

                    case 2:
                        VStack{
                            Text("What language would")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .drawingGroup()
                            
                            Text("you like to learn?")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .drawingGroup()
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        
                    case 3:
                        VStack{
                            Text("What should we call you?")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .drawingGroup()
                            
                        }
                        .frame(alignment: .top)
                        
                    case 4:
                        VStack(spacing: 00) {
                            Image("AppLogoPdf")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 290, height: 100, alignment: .center) // Adjust size as needed
                                .padding(.top, 30)
                        }
                        
                        Spacer(minLength: 40)
                        ZStack(){
                            VStack(spacing: 00) {
                                Text("Zero to Fluent\nthe easy way")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .drawingGroup()
                                
                                Text("\nTo get the most out of LiNGUiD, stop\ncaring about understanding every word.\nThe more relaxed you are, the more\nefficiently you will acquire your target\nlanguage. LiNGUiD is the best way to\nachieve true immersion. Forget\ndoomscrolling. From now on, you will be\nlanguage scrolling to fluency. Now all\nthe time you spend swiping will be time\nspent acquiring.\n")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                                    .drawingGroup()
                            }
                            .padding()
                            .background(Color(red: 62/255, green: 29/255, blue: 119/255))
                            .cornerRadius(8)
                            .padding()

                        }
                        Spacer()
                        
                        
                    default:
                        Text("Unknown Page")
                            .foregroundColor(.red)
                    }
                }
                Spacer()
            }
        //}
    //}
}


//struct OnboardingPageView_Previews: PreviewProvider {
//    static var previews: some View {
//        OnboardingPageView(index: 3)
//    }
//}
